const dbName = 'fin1';
const database = db.getSiblingDB(dbName);

const query = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  'metadata.receiptType': { $exists: false },
  $or: [
    { 'metadata.returnPercentage': { $exists: false } },
    { 'metadata.returnPercentage': null },
  ],
};

print('--- Inspect missing returnPercentage docs ---');
database.Document.find(query).limit(20).forEach((doc) => {
  printjson({
    id: doc._id,
    type: doc.type,
    tradeId: doc.tradeId,
    investmentId: doc.investmentId,
    metadata: doc.metadata || null,
  });
});
print('--- Done ---');
