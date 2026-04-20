// One-time migration:
// Backfill metadata.returnPercentage on investor collection bill documents.
//
// Usage example (on server):
// docker compose -f docker-compose.production.yml exec -T mongodb \
//   mongosh --quiet fin1 /tmp/backfill-collection-bill-return-percentage.js

const dbName = 'fin1';
const collName = 'Document';
const batchSize = 500;

function round2(value) {
  return Math.round(value * 100) / 100;
}

function isNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

const database = db.getSiblingDB(dbName);
const coll = database.getCollection(collName);

print('--- Backfill: metadata.returnPercentage on investor collection bills ---');

const query = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  'metadata.receiptType': { $exists: false },
  $or: [
    { 'metadata.returnPercentage': { $exists: false } },
    { 'metadata.returnPercentage': null },
  ],
};

let matched = 0;
let updated = 0;
let skippedMissingFields = 0;
let skippedInvalidValues = 0;
let processed = 0;

const cursor = coll.find(query);
let ops = [];

while (cursor.hasNext()) {
  const doc = cursor.next();
  matched += 1;
  processed += 1;

  const metadata = doc.metadata || {};
  const buyLeg = metadata.buyLeg || {};
  const fees = buyLeg.fees || {};

  let investedAmount = (buyLeg.amount || 0) + (fees.totalFees || 0);
  const netProfit = metadata.netProfit;

  // Legacy fallback: derive invested amount from AccountStatement "investment_activate"
  // for the same investment if buyLeg data is absent on older documents.
  if ((!isNumber(investedAmount) || investedAmount <= 0) && doc.investmentId) {
    const activation = database.AccountStatement.findOne(
      {
        userId: doc.userId,
        investmentId: doc.investmentId,
        entryType: 'investment_activate',
      },
      { sort: { createdAt: 1 } },
    );
    if (activation && isNumber(activation.amount) && activation.amount < 0) {
      investedAmount = Math.abs(activation.amount);
    }
  }

  // Legacy fallback: use Investment.amount when available.
  if ((!isNumber(investedAmount) || investedAmount <= 0) && doc.investmentId) {
    const investment = database.Investment.findOne({ _id: doc.investmentId });
    if (investment && isNumber(investment.amount) && investment.amount > 0) {
      investedAmount = investment.amount;
    }
  }

  if (!isNumber(netProfit) || !isNumber(investedAmount)) {
    skippedMissingFields += 1;
    continue;
  }

  if (investedAmount <= 0) {
    skippedInvalidValues += 1;
    continue;
  }

  const returnPercentage = round2((netProfit / investedAmount) * 100);
  ops.push({
    updateOne: {
      filter: { _id: doc._id },
      update: { $set: { 'metadata.returnPercentage': returnPercentage } },
    },
  });

  if (ops.length >= batchSize) {
    const result = coll.bulkWrite(ops, { ordered: false });
    updated += result.modifiedCount || 0;
    ops = [];
  }

  if (processed % 1000 === 0) {
    print(`... processed ${processed}`);
  }
}

if (ops.length > 0) {
  const result = coll.bulkWrite(ops, { ordered: false });
  updated += result.modifiedCount || 0;
}

print(`Matched: ${matched}`);
print(`Updated: ${updated}`);
print(`Skipped (missing/invalid number fields): ${skippedMissingFields}`);
print(`Skipped (investedAmount <= 0): ${skippedInvalidValues}`);
print('--- Done ---');
