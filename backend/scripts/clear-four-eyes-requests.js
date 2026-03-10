// ============================================================================
// Clear all FourEyesRequest documents (for testing only)
// ============================================================================
//
// FourEyesRequest is protected by beforeDelete in Parse (GoB). This script
// deletes directly in MongoDB so the trigger is bypassed. Use only in
// development/test to reset the 4-eyes workflow.
//
// Run with mongosh:
//
//   Local (Docker):
//     mongosh "mongodb://admin:fin1-mongo-password@localhost:27017/fin1?authSource=admin" --file backend/scripts/clear-four-eyes-requests.js
//
//   Or from host when MongoDB is in Docker:
//     docker exec -i fin1-mongodb mongosh "mongodb://admin:fin1-mongo-password@localhost:27017/fin1?authSource=admin" --file /dev/stdin < backend/scripts/clear-four-eyes-requests.js
//
//   Production: set MONGO_URI in env and run:
//     mongosh "$MONGO_URI" --file backend/scripts/clear-four-eyes-requests.js
//
// ============================================================================

const db = db.getSiblingDB('fin1');
const coll = db.getCollection('FourEyesRequest');

const countBefore = coll.countDocuments({});
print('FourEyesRequest documents before: ' + countBefore);

if (countBefore === 0) {
  print('Nothing to delete.');
  quit(0);
}

const result = coll.deleteMany({});
print('Deleted: ' + result.deletedCount);

const countAfter = coll.countDocuments({});
print('FourEyesRequest documents after: ' + countAfter);
print('Done. You can re-test the 4-eyes workflow from a clean state.');
