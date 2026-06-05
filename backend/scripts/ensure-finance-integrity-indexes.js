// Idempotent finance-integrity indexes: prevent duplicate backend cash bookings.
// Run on existing deployments:
//   mongosh fin1 ensure-finance-integrity-indexes.js
// Duplicate legacy rows must be repaired before unique indexes can be created.

db = db.getSiblingDB('fin1');

const TRADER_CASH_ENTRY_TYPES = ['trade_buy', 'trade_sell'];

function indexKeysToGroupId(keys) {
  const id = {};
  Object.keys(keys).forEach((field) => {
    id[field] = `$${field}`;
  });
  return id;
}

function countDuplicateGroups(groupIdExpr, extraMatch) {
  const rows = db.AccountStatement.aggregate([
    {
      $match: Object.assign({
        source: 'backend',
        entryType: { $in: TRADER_CASH_ENTRY_TYPES },
      }, extraMatch || {}),
    },
    {
      $group: {
        _id: groupIdExpr,
        count: { $sum: 1 },
        entryIds: { $push: '$_id' },
      },
    },
    { $match: { count: { $gt: 1 } } },
    { $limit: 20 },
  ]).toArray();
  return rows;
}

function tryCreateUniqueIndex(keys, name, partialFilterExpression) {
  const dups = countDuplicateGroups(indexKeysToGroupId(keys), partialFilterExpression);
  if (dups.length > 0) {
    print(`SKIP ${name}: ${dups.length} duplicate group(s) — repair before creating unique index`);
    dups.slice(0, 5).forEach((row) => printjson(row));
    return false;
  }
  try {
    db.AccountStatement.createIndex(keys, { unique: true, name, partialFilterExpression });
    print(`OK ${name}`);
    return true;
  } catch (e) {
    print(`ERROR ${name}: ${e && e.message ? e.message : String(e)}`);
    return false;
  }
}

print('=== Finance integrity indexes (AccountStatement) ===');

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, tradeId: 1 },
  'AccountStatement_backend_user_entry_tradeId_unique',
  {
    source: 'backend',
    tradeId: { $exists: true, $type: 'string' },
    entryType: { $in: TRADER_CASH_ENTRY_TYPES },
  },
);

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, businessCaseId: 1 },
  'AccountStatement_backend_user_entry_businessCase_unique',
  {
    source: 'backend',
    businessCaseId: { $exists: true, $type: 'string', $gt: '' },
    entryType: { $in: TRADER_CASH_ENTRY_TYPES },
  },
);

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, tradeNumber: 1 },
  'AccountStatement_backend_user_entry_tradeNumber_unique',
  {
    source: 'backend',
    tradeNumber: { $exists: true, $type: 'string', $gt: '' },
    entryType: { $in: TRADER_CASH_ENTRY_TYPES },
  },
);

db.OpsHealthSnapshot.createIndex({ kind: 1, runAt: -1 }, { name: 'OpsHealthSnapshot_kind_runAt' });

print('Done.');
