// Weekly reconciliation check for return% consistency.
// Focus: canonical collection-bill data quality by investment.
//
// Usage:
// docker compose -f docker-compose.production.yml exec -T mongodb \
//   mongosh --quiet --username admin --password "$MONGO_INITDB_ROOT_PASSWORD" \
//   --authenticationDatabase admin fin1 /tmp/weekly-return-percentage-reconciliation.js

const dbName = 'fin1';
const sampleLimit = 20;
const epsilon = 0.01; // allowed spread in percentage points
const database = db.getSiblingDB(dbName);
const coll = database.getCollection('Document');

const query = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  'metadata.receiptType': { $exists: false },
};

const docs = coll
  .find(query, {
    projection: {
      _id: 1,
      investmentId: 1,
      tradeId: 1,
      userId: 1,
      createdAt: 1,
      metadata: 1,
      type: 1,
    },
  })
  .sort({ createdAt: -1 })
  .limit(5000)
  .toArray();

const byInvestment = new Map();
let missingReturn = 0;
let invalidReturn = 0;

for (const doc of docs) {
  if (!doc.investmentId) continue;
  const ret = doc?.metadata?.returnPercentage;
  if (ret === undefined || ret === null) {
    missingReturn += 1;
    continue;
  }
  if (typeof ret !== 'number' || Number.isNaN(ret) || !Number.isFinite(ret)) {
    invalidReturn += 1;
    continue;
  }
  if (!byInvestment.has(doc.investmentId)) byInvestment.set(doc.investmentId, []);
  byInvestment.get(doc.investmentId).push({ returnPercentage: ret, id: doc._id, tradeId: doc.tradeId || null });
}

const drift = [];
for (const [investmentId, rows] of byInvestment.entries()) {
  if (rows.length < 2) continue;
  const values = rows.map((r) => r.returnPercentage);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const spread = max - min;
  if (spread > epsilon) {
    drift.push({
      investmentId,
      docs: rows.length,
      minReturnPercentage: min,
      maxReturnPercentage: max,
      spread,
      sampleDocIds: rows.slice(0, 3).map((r) => r.id),
    });
  }
}

print('--- Weekly return% reconciliation ---');
print(`checkedDocuments=${docs.length}`);
print(`investmentsChecked=${byInvestment.size}`);
print(`missingReturnPercentageCount=${missingReturn}`);
print(`invalidReturnPercentageCount=${invalidReturn}`);
print(`driftedInvestmentCount=${drift.length}`);
print(`healthy=${missingReturn === 0 && invalidReturn === 0 && drift.length === 0}`);

if (drift.length > 0) {
  print(`driftSamples(limit=${sampleLimit})=`);
  drift.slice(0, sampleLimit).forEach((entry) => printjson(entry));
}

print('--- Done ---');
