// Read-only: verify finance-integrity unique indexes exist (P0 prevention).
//   mongosh fin1 verify-finance-integrity-indexes.js
// Exit: prints index_status=healthy|degraded; use in ops / deploy smoke.

db = db.getSiblingDB('fin1');

const REQUIRED = [
  'AccountStatement_backend_trade_buy_user_tradeId_unique',
  'AccountStatement_backend_trade_buy_user_businessCase_unique',
  'AccountStatement_backend_trade_buy_user_tradeNumber_unique',
  'AccountStatement_backend_trade_sell_user_referenceDocument_unique',
];

const names = db.AccountStatement.getIndexes().map((i) => String(i.name || ''));
const missing = REQUIRED.filter((n) => !names.includes(n));

print('=== Verify finance integrity indexes ===');
print(`present=${REQUIRED.length - missing.length}/${REQUIRED.length}`);
if (missing.length > 0) {
  print('missing=' + missing.join(','));
  print('index_status=degraded');
  print('repairHint=mongosh fin1 ensure-finance-integrity-indexes.js');
  quit(1);
}

print('index_status=healthy');
quit(0);
