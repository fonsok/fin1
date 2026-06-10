// Idempotent finance-integrity indexes: prevent duplicate backend cash bookings.
// Run on existing deployments:
//   mongosh fin1 ensure-finance-integrity-indexes.js
// Duplicate legacy rows must be repaired before unique indexes can be created.

db = db.getSiblingDB('fin1');

const TRADER_CASH_ENTRY_TYPES = ['trade_buy', 'trade_sell'];

const LEGACY_INDEX_NAMES = [
  'AccountStatement_backend_user_entry_tradeId_unique',
  'AccountStatement_backend_user_entry_businessCase_unique',
  'AccountStatement_backend_user_entry_tradeNumber_unique',
];

const REQUIRED_INDEX_NAMES = [
  'AccountStatement_backend_trade_buy_user_tradeId_unique',
  'AccountStatement_backend_trade_buy_user_businessCase_unique',
  'AccountStatement_backend_trade_buy_user_tradeNumber_unique',
  'AccountStatement_backend_trade_sell_user_referenceDocument_unique',
];

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

function dropLegacyIndexes() {
  LEGACY_INDEX_NAMES.forEach((name) => {
    try {
      db.AccountStatement.dropIndex(name);
      print(`DROPPED legacy ${name}`);
    } catch (e) {
      if (e && String(e.message || e).indexOf('index not found') >= 0) {
        print(`SKIP drop ${name} (not found)`);
      } else {
        print(`WARN drop ${name}: ${e && e.message ? e.message : String(e)}`);
      }
    }
  });
}

print('=== Finance integrity indexes (AccountStatement) ===');

dropLegacyIndexes();

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, tradeId: 1 },
  'AccountStatement_backend_trade_buy_user_tradeId_unique',
  {
    source: 'backend',
    tradeId: { $exists: true, $type: 'string' },
    entryType: 'trade_buy',
  },
);

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, businessCaseId: 1 },
  'AccountStatement_backend_trade_buy_user_businessCase_unique',
  {
    source: 'backend',
    businessCaseId: { $exists: true, $type: 'string', $gt: '' },
    entryType: 'trade_buy',
  },
);

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, tradeNumber: 1 },
  'AccountStatement_backend_trade_buy_user_tradeNumber_unique',
  {
    source: 'backend',
    tradeNumber: { $exists: true, $type: 'string', $gt: '' },
    entryType: 'trade_buy',
  },
);

tryCreateUniqueIndex(
  { userId: 1, entryType: 1, referenceDocumentId: 1 },
  'AccountStatement_backend_trade_sell_user_referenceDocument_unique',
  {
    source: 'backend',
    referenceDocumentId: { $exists: true, $type: 'string', $gt: '' },
    entryType: 'trade_sell',
  },
);

db.OpsHealthSnapshot.createIndex({ kind: 1, runAt: -1 }, { name: 'OpsHealthSnapshot_kind_runAt' });

const present = db.AccountStatement.getIndexes().map((i) => String(i.name || ''));
const missing = REQUIRED_INDEX_NAMES.filter((n) => !present.includes(n));
if (missing.length) {
  print(`WARN missing required indexes: ${missing.join(', ')}`);
} else {
  print('All required finance-integrity indexes present.');
}

print('Done.');
