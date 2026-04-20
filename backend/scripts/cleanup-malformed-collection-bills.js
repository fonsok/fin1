// One-time cleanup:
// Archive malformed investor collection bill documents with missing metadata.
//
// Usage example (on server):
// docker compose -f docker-compose.production.yml exec -T mongodb \
//   mongosh --quiet fin1 /tmp/cleanup-malformed-collection-bills.js

const dbName = 'fin1';
const database = db.getSiblingDB(dbName);
const coll = database.getCollection('Document');

print('--- Cleanup malformed investor collection bills ---');

const query = {
  type: { $in: ['investorCollectionBill', 'investor_collection_bill'] },
  $or: [
    { metadata: { $exists: false } },
    { metadata: null },
  ],
};

const malformedDocs = coll.find(query).toArray();
print(`Found malformed docs: ${malformedDocs.length}`);

let updated = 0;
malformedDocs.forEach((doc) => {
  const res = coll.updateOne(
    { _id: doc._id },
    {
      $set: {
        type: 'investorCollectionBillArchived',
        source: 'legacy_cleanup',
        metadata: {
          cleanupReason: 'Malformed legacy investor collection bill (missing metadata)',
          archivedAt: new Date().toISOString(),
        },
      },
    },
  );
  updated += res.modifiedCount || 0;
});

const remaining = coll.countDocuments(query);
print(`Archived: ${updated}`);
print(`Remaining malformed in active types: ${remaining}`);
print('--- Done ---');
