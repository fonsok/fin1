// Monitoring query for daily cron/dashboard checks:
// Reports active investor collection bills missing metadata.returnPercentage.
//
// Usage example:
// docker compose -f docker-compose.production.yml exec -T mongodb \
//   mongosh --quiet fin1 /tmp/monitor-collection-bill-return-percentage.js

const dbName = 'fin1';
const database = db.getSiblingDB(dbName);
const coll = database.getCollection('Document');

const baseQuery = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  'metadata.receiptType': { $exists: false }, // exclude wallet receipts
};

const missingQuery = {
  ...baseQuery,
  $or: [
    { 'metadata.returnPercentage': { $exists: false } },
    { 'metadata.returnPercentage': null },
  ],
};

const totalActive = coll.countDocuments(baseQuery);
const missingCount = coll.countDocuments(missingQuery);
const samples = coll.find(missingQuery).sort({ createdAt: -1 }).limit(20).toArray();

print('--- Monitor collection bill returnPercentage ---');
print(`totalActiveCollectionBills=${totalActive}`);
print(`missingReturnPercentageCount=${missingCount}`);
print(`healthy=${missingCount === 0}`);

if (missingCount > 0) {
  print('sampleMissingDocuments=');
  samples.forEach((doc) => {
    printjson({
      objectId: doc._id,
      type: doc.type || null,
      tradeId: doc.tradeId || null,
      investmentId: doc.investmentId || null,
      createdAt: doc.createdAt || null,
    });
  });
}

print('--- Done ---');
