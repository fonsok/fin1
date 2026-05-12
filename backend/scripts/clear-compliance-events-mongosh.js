// Dev-only: remove all ComplianceEvent rows (e.g. legacy seed IDs that Parse delete rejects).
// Run on the Parse MongoDB (database fin1), e.g. on iobox from repo root:
//
//   mongosh "mongodb://admin:PASSWORD@127.0.0.1:27018/fin1?authSource=admin" backend/scripts/clear-compliance-events-mongosh.js
//
const db = db.getSiblingDB('fin1');
const n = db.ComplianceEvent.countDocuments({});
const r = db.ComplianceEvent.deleteMany({});
print(`ComplianceEvent: had ${n} docs, deleteMany deleted ${r.deletedCount}`);
