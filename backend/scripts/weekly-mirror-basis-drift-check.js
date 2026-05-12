// Weekly drift check: does the stored `metadata.returnPercentage` on each
// investorCollectionBill still agree with the mirror-basis SSOT
// (= deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate)) ?
//
// Invariant:
//   metadata.returnPercentage  ==  round2(netProfit / totalBuyCost * 100)
//   where
//     totalBuyCost   = buyLeg.amount  + buyLeg.fees.totalFees
//     netSellAmount  = sellLeg.amount - sellLeg.fees.totalFees
//     grossProfit    = netSellAmount - totalBuyCost
//     commission     = grossProfit > 0 ? grossProfit * commissionRate : 0
//     netProfit      = grossProfit - commission
//
// Run inside the mongodb container via the sibling wrapper
// `run-mirror-basis-drift-check.sh` once a week. Read-only; emits a short text
// report that the cron wrapper tails into syslog + log file.

/* global db, print, printjson */

const sampleLimit = 25;
const epsilonPp = 0.05; // pp drift tolerance between stored and derived ROI

const configCollection = db.getCollection('Config');
const coll = db.getCollection('Document');

function round2(n) {
  return Math.round(n * 100) / 100;
}
function isNum(v) {
  return typeof v === 'number' && Number.isFinite(v);
}

function loadCommissionRate() {
  try {
    const cfg = configCollection.findOne({});
    if (!cfg) return 0.11;
    if (isNum(cfg.traderCommissionRate)) return cfg.traderCommissionRate;
    if (cfg.params && isNum(cfg.params.traderCommissionRate)) return cfg.params.traderCommissionRate;
    if (cfg.params && cfg.params.traderCommissionRate && isNum(cfg.params.traderCommissionRate.value)) {
      return cfg.params.traderCommissionRate.value;
    }
  } catch (e) { /* fall through */ }
  return 0.11;
}

function deriveMirrorBasis(buyLeg, sellLeg, commissionRate) {
  if (!buyLeg || !sellLeg) return null;
  const buyFees = buyLeg.fees && isNum(buyLeg.fees.totalFees) ? buyLeg.fees.totalFees : 0;
  const sellFees = sellLeg.fees && isNum(sellLeg.fees.totalFees) ? sellLeg.fees.totalFees : 0;
  const totalBuyCost = round2((buyLeg.amount || 0) + buyFees);
  const netSellAmount = round2((sellLeg.amount || 0) - sellFees);
  const grossProfit = round2(netSellAmount - totalBuyCost);
  const commission = grossProfit > 0 ? round2(grossProfit * commissionRate) : 0;
  const netProfit = round2(grossProfit - commission);
  const returnPercentage = totalBuyCost > 0 ? round2((netProfit / totalBuyCost) * 100) : null;
  return { totalBuyCost, grossProfit, commission, netProfit, returnPercentage };
}

const commissionRate = loadCommissionRate();

const query = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  'metadata.receiptType': { $exists: false },
  'metadata.buyLeg': { $exists: true, $ne: null },
  'metadata.sellLeg': { $exists: true, $ne: null },
  'metadata.returnPercentage': { $exists: true, $type: 'number' },
};

const docs = coll.find(query).sort({ createdAt: -1 }).limit(5000).toArray();

let checked = 0;
let drifted = 0;
let nullDerived = 0;
const samples = [];

for (const doc of docs) {
  checked += 1;
  const meta = doc.metadata || {};
  const basis = deriveMirrorBasis(meta.buyLeg, meta.sellLeg, commissionRate);
  if (!basis || basis.returnPercentage === null) { nullDerived += 1; continue; }

  const storedReturn = meta.returnPercentage;
  const delta = Math.abs(storedReturn - basis.returnPercentage);
  if (delta > epsilonPp) {
    drifted += 1;
    if (samples.length < sampleLimit) {
      samples.push({
        docId: doc._id,
        investmentId: doc.investmentId,
        tradeId: doc.tradeId,
        storedReturnPercentage: storedReturn,
        derivedReturnPercentage: basis.returnPercentage,
        deltaPp: round2(delta),
        storedGrossProfit: meta.grossProfit,
        derivedGrossProfit: basis.grossProfit,
        backfillSource: meta.backfillSource || null,
      });
    }
  }
}

print('--- Weekly mirror-basis drift check ---');
print('commissionRate=' + commissionRate);
print('epsilonPp=' + epsilonPp);
print('checkedDocuments=' + checked);
print('driftedDocuments=' + drifted);
print('nullDerivedCount=' + nullDerived);
print('healthy=' + (drifted === 0));
if (samples.length > 0) {
  print('driftSamples(limit=' + sampleLimit + ')=');
  samples.forEach((entry) => printjson(entry));
}

// Admin-observability (2026-04-23): persist the latest run into the
// `OpsHealthSnapshot` collection so the `getMirrorBasisDriftStatus` Cloud
// function can surface it in the admin portal without SSH-tailing the log.
// Keep only the most recent run per check (`checkId` as _id).
try {
  const healthColl = db.getCollection('OpsHealthSnapshot');
  const now = new Date();
  const snapshot = {
    _id: 'mirror-basis-drift',
    kind: 'mirror-basis-drift',
    runAt: now,
    commissionRate,
    epsilonPp,
    checkedDocuments: checked,
    driftedDocuments: drifted,
    nullDerivedCount: nullDerived,
    healthy: drifted === 0,
    driftSamples: samples,
    // `updatedAt` helps ops see the freshness of the snapshot at a glance.
    updatedAt: now,
  };
  healthColl.replaceOne({ _id: snapshot._id }, snapshot, { upsert: true });
  print('snapshotWritten=OpsHealthSnapshot/mirror-basis-drift');
} catch (e) {
  print('snapshotWriteError=' + (e && e.message ? e.message : String(e)));
}
