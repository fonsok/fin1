// ============================================================================
// mongosh — Bulk migration: legacy customerId → userId (SupportTicket, SatisfactionSurvey)
// ============================================================================
//
// Wann: Bestehende MongoDB, auf der init/*.js beim ersten Start lief — danach nicht
//       erneut. Alte Dokumente können noch `customerId` haben; Cloud beforeSave
//       migriert bei jedem Save. Dieses Script migriert alle auf einmal ohne App.
//
// Ausführung (Beispiel, Passwort aus Server-.env):
//   docker compose -f docker-compose.production.yml exec -T mongodb \
//     mongosh "mongodb://admin:PASSWORD@127.0.0.1:27017/fin1?authSource=admin" \
//     < backend/mongodb/scripts/migrate_customerId_to_userId_fin1.js
//
// Oder in mongosh: load("/path/to/migrate_customerId_to_userId_fin1.js")
//
// Hinweis: Entspricht Logik in parse-server/cloud/triggers/support.js (userId
//          gewinnt, wenn beide gesetzt). _User (customerNumber) nicht hier —
//          dort Parse beforeSave / normalizeUserCustomerNumber.
// ============================================================================

db = db.getSiblingDB('fin1');

function migrateCollection(collName) {
  const coll = db.getCollection(collName);
  const before = coll.countDocuments({ customerId: { $exists: true } });
  if (before === 0) {
    print(`${collName}: no documents with customerId — skip`);
    return { collName, matched: 0, modified: 0 };
  }
  const res = coll.updateMany({ customerId: { $exists: true } }, [
    { $set: { userId: { $ifNull: ['$userId', '$customerId'] } } },
    { $unset: ['customerId'] },
  ]);
  print(`${collName}: matched ${res.matchedCount}, modified ${res.modifiedCount}`);
  return {
    collName,
    matched: res.matchedCount,
    modified: res.modifiedCount,
  };
}

print('=== migrate_customerId_to_userId_fin1 ===');
const out = [
  migrateCollection('SupportTicket'),
  migrateCollection('SatisfactionSurvey'),
];
printjson(out);
print('=== done ===');
