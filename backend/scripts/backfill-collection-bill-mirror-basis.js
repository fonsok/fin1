#!/usr/bin/env node
/* eslint-disable no-console */
//
// Backfill: rebuild investor Collection Bill `metadata.*` and the matching
// `PoolTradeParticipation` profit fields from the Mirror-Trade-Basis SSOT
// (`backend/parse-server/cloud/utils/accountingHelper/legs.js`).
//
// Background:
//   Before the 2026-04-20 Mirror-Basis refactor two bugs combined to store
//   inconsistent numbers on historical investor Collection Bills:
//     1. `settleAndDistribute` read `trade.get('entryPrice')` which is always
//        undefined — so `buyLeg`/`sellLeg` were never computed and `metadata`
//        fell through to the proportional fallback path.
//     2. The proportional fallback split the trader's net profit by ownership
//        share, which does NOT match a mirror-trade (each investor's leg is
//        bought with his own pool share at the trade's buy price, subject to
//        10-share quantity steps and his own fees).
//   This script recomputes the mirror-basis ground truth and rewrites the
//   denormalized copies so the stored DB values line up with the PDF bills
//   and the new `settleParticipation` path.
//
// What it touches (APPLY=1):
//   - Document(type ∈ {investorCollectionBill, investor_collection_bill}).metadata.{
//       grossProfit, commission, netProfit, returnPercentage, ownershipPercentage,
//       buyLeg, sellLeg, backfilledAt, backfillSource }
//   - PoolTradeParticipation.{ profitShare, commissionAmount, grossReturn,
//       profitBasis='mirror-backfill', backfilledAt }
//
// What it NEVER touches (reports advisories only):
//   - AccountStatement entries (investment_return, commission_debit,
//     commission_credit, residual_return). These represent real money
//     movements and must be corrected via explicit Storno + Re-Book with a
//     new Beleg — not mass-update.
//
// Usage:
//   MONGO_URL=mongodb://admin:<pw>@localhost:27017/fin1?authSource=admin \
//     node backend/scripts/backfill-collection-bill-mirror-basis.js
//   APPLY=1 MONGO_URL=... node backend/scripts/backfill-collection-bill-mirror-basis.js
//
// On the server (preferred, no tunnel needed):
//   ssh io@192.168.178.20 '
//     cd ~/fin1-server && \
//     docker compose exec -T mongodb sh -lc "cat > /tmp/backfill.js" < \
//       backend/scripts/backfill-collection-bill-mirror-basis.js
//   '
//   — OR run from inside the parse-server container which already has Node +
//   the legs.js module available (see scripts/run-backfill-on-server.sh).

'use strict';

const { MongoClient, ObjectId } = require('mongodb');

const path = require('path');
const fs = require('fs');

// Try to load the shared legs.js helpers from any of the known layouts so this
// script runs identically on a dev checkout and inside the parse-server
// container (`/app/cloud/...` vs. `backend/parse-server/cloud/...`).
function resolveLegsModule() {
  const candidates = [
    process.env.LEGS_MODULE_PATH,
    path.resolve(__dirname, '..', 'parse-server', 'cloud', 'utils', 'accountingHelper', 'legs.js'),
    '/app/cloud/utils/accountingHelper/legs.js',
  ].filter(Boolean);
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) return require(p);
    } catch (_) { /* keep trying */ }
  }
  throw new Error(`Could not find legs.js. Tried: ${candidates.join(', ')}`);
}

const {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
  deriveMirrorTradeBasis,
} = resolveLegsModule();

const mongoUrl = process.env.MONGO_URL
  || 'mongodb://admin:QgQl3nnPdIuA7ZxIq9IviL3OItM5FLTI@localhost:27017/fin1?authSource=admin';
const dbName = process.env.MONGO_DB || 'fin1';
const applyChanges = process.env.APPLY === '1';
const sampleLimit = Number(process.env.SAMPLE_LIMIT || 20);
const restrictToDocId = process.env.DOC_ID || null;

function round2(n) {
  return Math.round(n * 100) / 100;
}

function isNum(v) {
  return typeof v === 'number' && Number.isFinite(v);
}

function eq2(a, b) {
  return isNum(a) && isNum(b) && Math.abs(round2(a) - round2(b)) < 0.01;
}

async function loadCommissionRate(database) {
  // Production config is typically in `Config` (Parse) or `_GlobalConfig`. Try a
  // few known shapes; default to 0.11 (the value the admin panel currently
  // displays per the 2026-04 conversation with the user).
  const collections = ['Config', '_GlobalConfig'];
  for (const col of collections) {
    try {
      const row = await database.collection(col).findOne({});
      if (!row) continue;
      if (isNum(row.traderCommissionRate)) return row.traderCommissionRate;
      if (row.params && isNum(row.params.traderCommissionRate)) return row.params.traderCommissionRate;
      if (row.params && row.params.traderCommissionRate && isNum(row.params.traderCommissionRate.value)) {
        return row.params.traderCommissionRate.value;
      }
    } catch (_) {
      /* ignore */
    }
  }
  return 0.11;
}

async function loadFeeConfig(database) {
  // Prefer explicit admin-managed fee config; otherwise fall back to
  // `legs.js` DEFAULTS (orderFeeRate 0.005 min 5 max 50; exchange 0.001 min 1
  // max 20; foreignCosts 1.50). We return an object with the keys
  // `calculateOrderFees` in parse-server/cloud/utils/helpers.js reads.
  const defaults = {
    orderFeeRate: 0.005,
    orderFeeMin: 5,
    orderFeeMax: 50,
    exchangeFeeRate: 0.001,
    exchangeFeeMin: 1,
    exchangeFeeMax: 20,
    foreignCosts: 1.50,
  };
  try {
    const cfg = await database.collection('Config').findOne({});
    if (!cfg) return defaults;
    const params = cfg.params || {};
    const merged = { ...defaults };
    for (const key of Object.keys(defaults)) {
      if (isNum(params[key])) merged[key] = params[key];
      if (params[key] && isNum(params[key].value)) merged[key] = params[key].value;
    }
    return merged;
  } catch (_) {
    return defaults;
  }
}

function resolveTradePrices(trade) {
  if (!trade) return { buyPrice: 0, sellPrice: 0, sellQuantity: 0 };
  const buyOrder = trade.buyOrder || {};
  const sellOrders = Array.isArray(trade.sellOrders) ? trade.sellOrders : [];
  const firstSell = sellOrders[0] || trade.sellOrder || {};
  const buyPrice = Number(trade.entryPrice)
    || Number(trade.buyPrice)
    || Number(buyOrder.price)
    || 0;
  const sellPrice = Number(trade.exitPrice)
    || Number(trade.sellPrice)
    || Number(firstSell.price)
    || Number(firstSell.limitPrice)
    || 0;
  const sellQuantity = Number(firstSell.quantity)
    || Number(firstSell.filledQuantity)
    || Number(trade.quantity)
    || 0;
  return { buyPrice, sellPrice, sellQuantity };
}

async function main() {
  console.log('=== Collection Bill Mirror-Basis Backfill ===');
  console.log(`mongoUrl        = ${mongoUrl.replace(/:\/\/[^@]+@/, '://<redacted>@')}`);
  console.log(`database        = ${dbName}`);
  console.log(`mode            = ${applyChanges ? 'APPLY (writes enabled)' : 'DRY-RUN (no writes)'}`);
  console.log(`sampleLimit     = ${sampleLimit}`);
  if (restrictToDocId) console.log(`restrictToDocId = ${restrictToDocId}`);
  console.log('');

  const client = new MongoClient(mongoUrl);
  await client.connect();
  try {
    const database = client.db(dbName);
    const documents = database.collection('Document');
    const participations = database.collection('PoolTradeParticipation');
    const trades = database.collection('Trade');
    const investments = database.collection('Investment');
    const accountStatements = database.collection('AccountStatement');

    const commissionRate = await loadCommissionRate(database);
    const feeConfig = await loadFeeConfig(database);
    console.log(`commissionRate  = ${commissionRate}`);
    console.log(`feeConfig       = ${JSON.stringify(feeConfig)}`);
    console.log('');

    const baseQuery = {
      type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
      'metadata.receiptType': { $exists: false },
    };
    if (restrictToDocId) {
      try {
        baseQuery._id = new ObjectId(restrictToDocId);
      } catch (_) {
        baseQuery._id = restrictToDocId;
      }
    }

    const cursor = documents.find(baseQuery).sort({ createdAt: -1 });

    let checked = 0;
    let reconstructed = 0;
    let drifted = 0;
    let skippedNoTrade = 0;
    let skippedNoInvestment = 0;
    let skippedNoPrice = 0;
    let updatedBills = 0;
    let updatedParticipations = 0;
    let advisoryAccountStatements = 0;
    const driftSamples = [];
    const accountStmtAdvisories = [];

    for await (const doc of cursor) {
      checked += 1;
      const meta = doc.metadata || {};

      const investmentId = doc.investmentId || (meta.investmentId || null);
      const tradeId = doc.tradeId || (meta.tradeId || null);
      const userId = doc.userId || null;

      if (!investmentId || !tradeId) {
        skippedNoTrade += 1;
        continue;
      }

      const investment = await investments.findOne({
        $or: [{ _id: investmentId }, { objectId: investmentId }],
      });
      if (!investment) {
        skippedNoInvestment += 1;
        continue;
      }
      const investmentCapital = Number(investment.amount) || 0;

      const trade = await trades.findOne({
        $or: [{ _id: tradeId }, { objectId: tradeId }],
      });
      if (!trade) {
        skippedNoTrade += 1;
        continue;
      }

      const { buyPrice, sellPrice, sellQuantity } = resolveTradePrices(trade);
      if (buyPrice <= 0 || sellPrice <= 0) {
        skippedNoPrice += 1;
        continue;
      }

      // Phase A SSOT reconstruction — same helpers as `settleParticipation`.
      const buyLeg = computeInvestorBuyLeg(investmentCapital, buyPrice, feeConfig);
      if (!buyLeg || !buyLeg.quantity) {
        skippedNoPrice += 1;
        continue;
      }
      // `computeInvestorSellLeg(qty, sellPrice, sellFraction=1.0, feeConfig)` —
      // the pool sells 100 % of the shares it bought, so fraction = 1.0 aligns
      // with the live settleParticipation path.
      const sellLeg = computeInvestorSellLeg(buyLeg.quantity, sellPrice, 1.0, feeConfig);
      const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate);
      if (!basis) continue;
      reconstructed += 1;

      const storedGross = meta.grossProfit;
      const storedComm = meta.commission;
      const storedNet = meta.netProfit;
      const storedRet = meta.returnPercentage;

      const grossMismatch = !eq2(storedGross, basis.grossProfit);
      const commMismatch = !eq2(storedComm, basis.commission);
      const netMismatch = !eq2(storedNet, basis.netProfit);
      const retMismatch = !eq2(storedRet, basis.returnPercentage);
      const buyLegMissing = !meta.buyLeg || !meta.buyLeg.quantity;
      const sellLegMissing = !meta.sellLeg || !meta.sellLeg.quantity;

      if (!grossMismatch && !commMismatch && !netMismatch && !retMismatch
          && !buyLegMissing && !sellLegMissing) {
        continue;
      }
      drifted += 1;

      if (driftSamples.length < sampleLimit) {
        driftSamples.push({
          docId: doc._id,
          investmentId,
          tradeId,
          userId,
          investmentCapital,
          buyPrice,
          sellPrice,
          sellQuantity,
          stored: {
            grossProfit: storedGross,
            commission: storedComm,
            netProfit: storedNet,
            returnPercentage: storedRet,
            hasBuyLeg: !buyLegMissing,
            hasSellLeg: !sellLegMissing,
          },
          mirrorBasis: {
            grossProfit: basis.grossProfit,
            commission: basis.commission,
            netProfit: basis.netProfit,
            returnPercentage: basis.returnPercentage,
            buyLeg: { quantity: buyLeg.quantity, amount: buyLeg.amount, fees: buyLeg.fees, residual: buyLeg.residualAmount },
            sellLeg: { quantity: sellLeg.quantity, amount: sellLeg.amount, fees: sellLeg.fees },
          },
        });
      }

      // --- AccountStatement advisory (read-only) ---
      try {
        const investmentReturn = await accountStatements.findOne({
          userId,
          investmentId,
          entryType: 'investment_return',
        });
        const commDebit = await accountStatements.findOne({
          userId,
          investmentId,
          entryType: 'commission_debit',
        });

        const expectedReturn = isNum(investmentCapital) ? round2(investmentCapital + basis.grossProfit) : null;
        const expectedCommDebit = -Math.abs(basis.commission);

        const returnDrift = investmentReturn && isNum(expectedReturn)
          && !eq2(investmentReturn.amount, expectedReturn);
        const commDebitDrift = commDebit && !eq2(commDebit.amount, expectedCommDebit);

        if (returnDrift || commDebitDrift) {
          advisoryAccountStatements += 1;
          if (accountStmtAdvisories.length < sampleLimit) {
            accountStmtAdvisories.push({
              investmentId,
              userId,
              investment_return: investmentReturn ? {
                storedAmount: investmentReturn.amount,
                expectedAmount: expectedReturn,
                entryId: investmentReturn._id,
              } : null,
              commission_debit: commDebit ? {
                storedAmount: commDebit.amount,
                expectedAmount: expectedCommDebit,
                entryId: commDebit._id,
              } : null,
              note: 'REAL MONEY MOVEMENT — requires manual Storno + Re-Book with new Beleg',
            });
          }
        }
      } catch (_) {
        /* best-effort */
      }

      if (applyChanges) {
        const setObj = {
          'metadata.grossProfit': basis.grossProfit,
          'metadata.commission': basis.commission,
          'metadata.netProfit': basis.netProfit,
          'metadata.returnPercentage': basis.returnPercentage,
          'metadata.buyLeg': buyLeg,
          'metadata.sellLeg': sellLeg,
          'metadata.backfilledAt': new Date(),
          'metadata.backfillSource': 'mirror-basis-phase-a',
        };
        const res = await documents.updateOne({ _id: doc._id }, { $set: setObj });
        if (res.modifiedCount) updatedBills += res.modifiedCount;

        const participation = await participations.findOne({
          $or: [
            { investmentId, tradeId },
            { 'investment.objectId': investmentId, 'trade.objectId': tradeId },
          ],
        });
        if (participation) {
          const pRes = await participations.updateOne(
            { _id: participation._id },
            {
              $set: {
                profitShare: basis.grossProfit,
                commissionAmount: basis.commission,
                grossReturn: basis.netProfit,
                profitBasis: 'mirror-backfill',
                backfilledAt: new Date(),
              },
            },
          );
          if (pRes.modifiedCount) updatedParticipations += pRes.modifiedCount;
        }
      }
    }

    console.log(`checked                      = ${checked}`);
    console.log(`reconstructedLegs            = ${reconstructed}`);
    console.log(`driftedDocuments             = ${drifted}`);
    console.log(`skippedNoTrade               = ${skippedNoTrade}`);
    console.log(`skippedNoInvestment          = ${skippedNoInvestment}`);
    console.log(`skippedNoPrice               = ${skippedNoPrice}`);
    console.log(`advisoryAccountStatements    = ${advisoryAccountStatements}`);
    console.log('');
    console.log(`applied: bills=${updatedBills}, participations=${updatedParticipations}`);
    console.log('');

    if (driftSamples.length > 0) {
      console.log(`--- Drift samples (limit=${sampleLimit}) ---`);
      for (const s of driftSamples) {
        console.log(JSON.stringify(s, null, 2));
      }
    }

    if (accountStmtAdvisories.length > 0) {
      console.log('');
      console.log(`--- AccountStatement advisories (limit=${sampleLimit}, NOT modified) ---`);
      console.log('These entries represent real money movements whose historical amounts');
      console.log('differ from the mirror-basis expectation. Each case needs an individual');
      console.log('Storno + Re-Book with its own Beleg. The script deliberately does NOT');
      console.log('touch AccountStatement.');
      console.log('');
      for (const a of accountStmtAdvisories) {
        console.log(JSON.stringify(a, null, 2));
      }
    }

    console.log('');
    console.log('--- Done ---');
  } finally {
    await client.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
