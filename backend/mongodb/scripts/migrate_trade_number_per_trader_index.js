/**
 * Trade.tradeNumber must be unique per trader, not globally.
 *
 * Without this, trader B cannot persist trade #1 when trader A already has trade #1
 * (upsertTrade E11000) → local-only trade on iOS → pool activation never runs → investments stay reserved.
 *
 * Run on iobox:
 *   source ~/fin1-server/.env
 *   cat backend/mongodb/scripts/migrate_trade_number_per_trader_index.js | docker exec -i fin1-mongodb \
 *     mongosh --quiet -u admin -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin
 */

db = db.getSiblingDB('fin1');

const coll = db.Trade;
const legacyIndex = 'tradeNumber_1';
const compoundIndex = 'traderId_1_tradeNumber_1';

print('=== migrate_trade_number_per_trader_index: start ===');

const duplicates = coll.aggregate([
  { $match: { tradeNumber: { $type: 'number' } } },
  { $group: { _id: '$tradeNumber', traders: { $addToSet: '$traderId' }, count: { $sum: 1 } } },
  { $match: { count: { $gt: 1 } } },
]).toArray();

if (duplicates.length > 0) {
  print('WARN: global duplicate tradeNumber groups (expected until compound index is live):');
  duplicates.forEach((row) => printjson(row));
}

try {
  coll.dropIndex(legacyIndex);
  print('Dropped legacy index ' + legacyIndex);
} catch (e) {
  print('dropIndex ' + legacyIndex + ': ' + e.message);
}

const existing = coll.getIndexes().find((i) => i.name === compoundIndex);
if (existing && existing.unique === true) {
  print('OK compound index already present');
} else {
  if (existing) {
    try { coll.dropIndex(compoundIndex); } catch (e) { print('drop compound warn: ' + e.message); }
  }
  coll.createIndex({ traderId: 1, tradeNumber: 1 }, { unique: true, sparse: true, name: compoundIndex });
  print('Created ' + compoundIndex + ' (unique+sparse)');
}

print('=== migrate_trade_number_per_trader_index: done ===');
