// Weekly drift check: stored `metadata.returnPercentage` vs mirror-basis SSOT.
// Requires opsFinanceSsot.mongodb.js prepended by run-finance-integrity-snapshots.sh.

/* global db, print, printjson, deriveMirrorTradeBasis, loadCommissionRate, resolveCommissionRate, writeOpsHealthSnapshot */

const sampleLimit = 25;
const epsilonPp = 0.05;
const coll = db.getCollection('Document');
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
  const billCommissionRate = resolveCommissionRate(meta);
  const basis = deriveMirrorTradeBasis(meta.buyLeg, meta.sellLeg, billCommissionRate);
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
print(`commissionRate=${commissionRate}`);
print(`epsilonPp=${epsilonPp}`);
print(`checkedDocuments=${checked}`);
print(`driftedDocuments=${drifted}`);
print(`nullDerivedCount=${nullDerived}`);
print(`healthy=${drifted === 0}`);
if (samples.length > 0) {
  print(`driftSamples(limit=${sampleLimit})=`);
  samples.forEach((entry) => printjson(entry));
}

try {
  writeOpsHealthSnapshot({
    _id: 'mirror-basis-drift',
    kind: 'mirror-basis-drift',
    commissionRate,
    epsilonPp,
    checkedDocuments: checked,
    driftedDocuments: drifted,
    nullDerivedCount: nullDerived,
    healthy: drifted === 0,
    driftSamples: samples,
  });
  print('snapshotWritten=OpsHealthSnapshot/mirror-basis-drift');
} catch (e) {
  print(`snapshotWriteError=${e && e.message ? e.message : String(e)}`);
}
