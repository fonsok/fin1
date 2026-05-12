// Reconciliation & backfill: align Investor Collection Bill `metadata.*` and
// PoolTradeParticipation profit/commission/net with the Mirror-Trade-Basis SSOT
// (buyLeg/sellLeg line items). AccountStatement entries are reported as advisory
// only — never auto-rewritten, because they represent real money movements.
//
// Usage (dry-run, default):
//   docker compose -f docker-compose.production.yml exec -T mongodb \
//     mongosh --quiet --username admin --password "$MONGO_INITDB_ROOT_PASSWORD" \
//     --authenticationDatabase admin fin1 /tmp/reconcile-collection-bill-mirror-basis.js
//
// To apply changes:
//   APPLY=1 docker compose ... mongosh ... /tmp/reconcile-collection-bill-mirror-basis.js
//
// Scope of writes when APPLY=1:
//   - Document.metadata.{grossProfit, commission, netProfit, returnPercentage, ownershipPercentage}
//   - PoolTradeParticipation.{profitShare, commissionAmount, grossReturn, profitBasis='mirror-backfill'}
//
// NOT touched:
//   - AccountStatement.* (investment_return, commission_debit, commission_credit,
//     residual_return) — reported as advisory; real money movements must be
//     fixed via explicit Storno+Re-Book with their own Beleg, not mass update.

const dbName = 'fin1';
const applyChanges = (typeof process !== 'undefined' && process.env && process.env.APPLY === '1');
const sampleLimit = 20;
const database = db.getSiblingDB(dbName);
const documents = database.getCollection('Document');
const participations = database.getCollection('PoolTradeParticipation');
const accountStatements = database.getCollection('AccountStatement');
const configCollection = database.getCollection('Config');

function round2(n) { return Math.round(n * 100) / 100; }
function isNum(v) { return typeof v === 'number' && Number.isFinite(v); }
function eq2(a, b) { return isNum(a) && isNum(b) && Math.abs(round2(a) - round2(b)) < 0.01; }

function loadCommissionRate() {
  // Try a few known shapes. Defaults to 0.11 (current production value).
  try {
    const cfg = configCollection.findOne({ _id: 'traderCommissionRate' });
    if (cfg && isNum(cfg.value)) return cfg.value;
  } catch (_) {}
  try {
    const cfg = configCollection.findOne({});
    if (cfg && isNum(cfg.traderCommissionRate)) return cfg.traderCommissionRate;
    if (cfg && cfg.params && isNum(cfg.params.traderCommissionRate)) return cfg.params.traderCommissionRate;
  } catch (_) {}
  return 0.11;
}

function deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate) {
  if (!buyLeg || !sellLeg) return null;
  const buyFees = buyLeg.fees && isNum(buyLeg.fees.totalFees) ? buyLeg.fees.totalFees : 0;
  const sellFees = sellLeg.fees && isNum(sellLeg.fees.totalFees) ? sellLeg.fees.totalFees : 0;
  const buyAmt = isNum(buyLeg.amount) ? buyLeg.amount : 0;
  const sellAmt = isNum(sellLeg.amount) ? sellLeg.amount : 0;
  const totalBuyCost = round2(buyAmt + buyFees);
  const netSellAmount = round2(sellAmt - sellFees);
  const grossProfit = round2(netSellAmount - totalBuyCost);
  const commission = grossProfit > 0 ? round2(grossProfit * commissionRate) : 0;
  const netProfit = round2(grossProfit - commission);
  const returnPercentage = totalBuyCost > 0 ? round2((netProfit / totalBuyCost) * 100) : null;
  return { totalBuyCost, netSellAmount, grossProfit, commission, netProfit, returnPercentage };
}

const commissionRate = loadCommissionRate();

print('=== Collection Bill Mirror-Basis Reconciliation ===');
print(`mode                 = ${applyChanges ? 'APPLY (writes enabled)' : 'DRY-RUN (no writes)'}`);
print(`commissionRate       = ${commissionRate}`);
print(`sampleLimit          = ${sampleLimit}`);
print('');

const query = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  'metadata.receiptType': { $exists: false },
  'metadata.buyLeg': { $exists: true, $ne: null },
  'metadata.sellLeg': { $exists: true, $ne: null },
};

const cursor = documents.find(query).sort({ createdAt: -1 });

let checked = 0;
let drifted = 0;
let skippedNoLegs = 0;
let skippedNullReturn = 0;
let updatedBills = 0;
let updatedParticipations = 0;
let advisoryAccountStatements = 0;
const driftSamples = [];
const accountStmtAdvisories = [];

while (cursor.hasNext()) {
  const doc = cursor.next();
  checked += 1;
  const meta = doc.metadata || {};
  const buyLeg = meta.buyLeg;
  const sellLeg = meta.sellLeg;

  const basis = deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate);
  if (!basis) {
    skippedNoLegs += 1;
    continue;
  }
  if (basis.returnPercentage === null) {
    skippedNullReturn += 1;
    continue;
  }

  const storedGross = meta.grossProfit;
  const storedComm = meta.commission;
  const storedNet = meta.netProfit;
  const storedRet = meta.returnPercentage;

  const grossMismatch = !eq2(storedGross, basis.grossProfit);
  const commMismatch = !eq2(storedComm, basis.commission);
  const netMismatch = !eq2(storedNet, basis.netProfit);
  const retMismatch = !eq2(storedRet, basis.returnPercentage);

  if (!grossMismatch && !commMismatch && !netMismatch && !retMismatch) continue;

  drifted += 1;

  if (driftSamples.length < sampleLimit) {
    driftSamples.push({
      docId: doc._id,
      investmentId: doc.investmentId,
      tradeId: doc.tradeId,
      userId: doc.userId,
      stored: { grossProfit: storedGross, commission: storedComm, netProfit: storedNet, returnPercentage: storedRet },
      mirror: { grossProfit: basis.grossProfit, commission: basis.commission, netProfit: basis.netProfit, returnPercentage: basis.returnPercentage },
    });
  }

  // --- Collect AccountStatement advisories (read-only) ---
  if (doc.investmentId) {
    try {
      const investmentReturn = accountStatements.findOne({
        userId: doc.userId,
        investmentId: doc.investmentId,
        entryType: 'investment_return',
      });
      const commDebit = accountStatements.findOne({
        userId: doc.userId,
        investmentId: doc.investmentId,
        entryType: 'commission_debit',
      });

      const investment = database.Investment.findOne({ _id: doc.investmentId });
      const capital = investment && isNum(investment.amount) ? investment.amount : null;
      const expectedReturn = isNum(capital) ? round2(capital + basis.grossProfit) : null;
      const expectedCommDebit = -Math.abs(basis.commission);

      const returnDrift = investmentReturn && isNum(expectedReturn) && !eq2(investmentReturn.amount, expectedReturn);
      const commDebitDrift = commDebit && !eq2(commDebit.amount, expectedCommDebit);

      if (returnDrift || commDebitDrift) {
        advisoryAccountStatements += 1;
        if (accountStmtAdvisories.length < sampleLimit) {
          accountStmtAdvisories.push({
            investmentId: doc.investmentId,
            userId: doc.userId,
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
            note: 'REAL MONEY MOVEMENT — requires manual Storno+Re-Book with new Beleg',
          });
        }
      }
    } catch (e) {
      // AccountStatement lookup is best-effort; advisory only.
    }
  }

  // --- Apply writes if APPLY=1 ---
  if (applyChanges) {
    const res = documents.updateOne(
      { _id: doc._id },
      {
        $set: {
          'metadata.grossProfit': basis.grossProfit,
          'metadata.commission': basis.commission,
          'metadata.netProfit': basis.netProfit,
          'metadata.returnPercentage': basis.returnPercentage,
          'metadata.backfilledAt': new Date(),
          'metadata.backfillSource': 'mirror-basis-reconcile',
        },
      }
    );
    if (res && res.modifiedCount) updatedBills += res.modifiedCount;

    // Also update the matching PoolTradeParticipation so app/admin reads stay in sync.
    if (doc.investmentId && doc.tradeId) {
      const participation = participations.findOne({
        investmentId: doc.investmentId,
        tradeId: doc.tradeId,
      });
      if (participation) {
        const pRes = participations.updateOne(
          { _id: participation._id },
          {
            $set: {
              profitShare: basis.grossProfit,
              commissionAmount: basis.commission,
              grossReturn: basis.netProfit,
              profitBasis: 'mirror-backfill',
              backfilledAt: new Date(),
            },
          }
        );
        if (pRes && pRes.modifiedCount) updatedParticipations += pRes.modifiedCount;
      }
    }
  }
}

print(`checked                         = ${checked}`);
print(`driftedDocuments                = ${drifted}`);
print(`skippedMissingLegs              = ${skippedNoLegs}`);
print(`skippedNullReturnPercentage     = ${skippedNullReturn}`);
print(`advisoryAccountStatementDiffs   = ${advisoryAccountStatements}`);
print('');
print(`applied: bills=${updatedBills}, participations=${updatedParticipations}`);
print('');

if (driftSamples.length > 0) {
  print(`--- Drift samples (limit=${sampleLimit}) ---`);
  driftSamples.forEach((s) => printjson(s));
}

if (accountStmtAdvisories.length > 0) {
  print('');
  print(`--- AccountStatement advisories (limit=${sampleLimit}, NOT modified) ---`);
  print('These entries represent real money movements whose historical amounts');
  print('differ from the mirror-basis expectation. Each case needs an individual');
  print('Storno + Re-Book with its own Beleg. The reconciliation script deliberately');
  print('does NOT touch AccountStatement.');
  print('');
  accountStmtAdvisories.forEach((a) => printjson(a));
}

print('');
print('--- Done ---');
