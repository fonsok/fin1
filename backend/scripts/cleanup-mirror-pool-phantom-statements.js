// ============================================================================
// Remove phantom trader AccountStatement rows linked to MIRROR_POOL trades.
//
// These rows were created before mirror-leg guards existed (pool-only buys/sells
// incorrectly booked on the trader Personenkonto).
//
// Usage (dry-run default):
//   CONFIRM_MIRROR_POOL_STMT_CLEANUP=1 ./backend/scripts/cleanup-mirror-pool-phantom-statements.sh
//
// On server:
//   cd ~/fin1-server/scripts && CONFIRM_MIRROR_POOL_STMT_CLEANUP=1 ./cleanup-mirror-pool-phantom-statements.sh
// ============================================================================

const dbName = 'fin1';
const database = db.getSiblingDB(dbName);

const EXECUTE = (
  (typeof CONFIRM_MIRROR_POOL_STMT_CLEANUP !== 'undefined'
    && String(CONFIRM_MIRROR_POOL_STMT_CLEANUP) === '1')
  || (typeof process !== 'undefined'
    && process.env
    && process.env.CONFIRM_MIRROR_POOL_STMT_CLEANUP === '1')
);

const TRADER_MIRROR_STMT_TYPES = [
  'trade_buy',
  'trade_sell',
  'trading_fees',
  'commission_credit',
];

function round2(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.round(n * 100) / 100;
}

function tradeIdString(value) {
  if (!value) return null;
  if (typeof value === 'string') return value.trim() || null;
  if (value.$oid) return String(value.$oid);
  if (value.toString) return String(value.toString());
  return null;
}

function loadMirrorTradeContext() {
  const tradeById = new Map();
  const traderIdByMirrorTradeId = new Map();

  database.Trade.find({ buyLegType: 'MIRROR_POOL' }).forEach((trade) => {
    const id = tradeIdString(trade._id);
    if (!id) return;
    tradeById.set(id, trade);
    const traderId = String(trade.traderId || '').trim();
    if (traderId) traderIdByMirrorTradeId.set(id, traderId);
  });

  database.Order.find({ legType: 'MIRROR_POOL' }).forEach((order) => {
    const id = tradeIdString(order.tradeId);
    if (!id) return;
    const traderId = String(order.traderId || '').trim();
    if (traderId && !traderIdByMirrorTradeId.has(id)) {
      traderIdByMirrorTradeId.set(id, traderId);
    }
  });

  return { tradeById, traderIdByMirrorTradeId };
}

function isPhantomTraderMirrorStatement(row, traderIdByMirrorTradeId) {
  const tradeId = tradeIdString(row.tradeId);
  if (!tradeId || !traderIdByMirrorTradeId.has(tradeId)) return false;

  const entryType = String(row.entryType || '');
  if (!TRADER_MIRROR_STMT_TYPES.includes(entryType)) return false;

  const traderId = traderIdByMirrorTradeId.get(tradeId);
  const rowUserId = String(row.userId || '').trim();
  return rowUserId === traderId;
}

function rebuildBalanceChainForUser(userId) {
  const stmtColl = database.AccountStatement;
  const rows = stmtColl
    .find({ userId })
    .sort({ _created_at: 1, _id: 1 })
    .toArray();

  if (rows.length === 0) {
    database.UserCashBalance.updateOne(
      { userId },
      { $set: { userId, currentBalance: 0 } },
      { upsert: true },
    );
    return { userId, rowsUpdated: 0, currentBalance: 0 };
  }

  let running = round2(rows[0].balanceBefore ?? 0);
  let rowsUpdated = 0;

  rows.forEach((row) => {
    const amount = round2(row.amount ?? 0);
    const balanceBefore = running;
    const balanceAfter = round2(running + amount);
    running = balanceAfter;

    if (row.balanceBefore !== balanceBefore || row.balanceAfter !== balanceAfter) {
      stmtColl.updateOne(
        { _id: row._id },
        { $set: { balanceBefore, balanceAfter } },
      );
      rowsUpdated += 1;
    }
  });

  database.UserCashBalance.updateOne(
    { userId },
    { $set: { userId, currentBalance: running } },
    { upsert: true },
  );

  return { userId, rowsUpdated, currentBalance: running };
}

print('--- Cleanup phantom MIRROR_POOL AccountStatement rows ---');
print(`Mode: ${EXECUTE ? 'EXECUTE' : 'DRY-RUN (set CONFIRM_MIRROR_POOL_STMT_CLEANUP=1 to delete)'}`);

const { traderIdByMirrorTradeId } = loadMirrorTradeContext();
print(`Mirror pool trade ids: ${traderIdByMirrorTradeId.size}`);

if (traderIdByMirrorTradeId.size === 0) {
  print('No MIRROR_POOL trades found — nothing to clean.');
  print('--- Done ---');
  quit(0);
}

const mirrorTradeIdList = Array.from(traderIdByMirrorTradeId.keys());
const candidateRows = database.AccountStatement.find({
  tradeId: { $in: mirrorTradeIdList },
  entryType: { $in: TRADER_MIRROR_STMT_TYPES },
}).sort({ _created_at: 1 }).toArray();

const phantomRows = candidateRows.filter((row) => isPhantomTraderMirrorStatement(row, traderIdByMirrorTradeId));
print(`Phantom AccountStatement rows: ${phantomRows.length}`);

if (phantomRows.length === 0) {
  print('No phantom rows found — database already clean.');
  print('--- Done ---');
  quit(0);
}

phantomRows.forEach((row) => {
  print(JSON.stringify({
    id: String(row._id),
    userId: row.userId || null,
    tradeId: row.tradeId || null,
    entryType: row.entryType || null,
    amount: row.amount ?? null,
    referenceDocumentNumber: row.referenceDocumentNumber || null,
    createdAt: row._created_at || null,
  }));
});

const affectedUsers = [...new Set(
  phantomRows.map((row) => String(row.userId || '').trim()).filter(Boolean),
)];
print(`Affected users: ${affectedUsers.length}`);

if (!EXECUTE) {
  print('Dry-run complete. Re-run with CONFIRM_MIRROR_POOL_STMT_CLEANUP=1 to delete and rebuild balances.');
  print('--- Done ---');
  quit(0);
}

const deleteIds = phantomRows.map((row) => String(row._id));
const deleteResult = database.AccountStatement.deleteMany({ _id: { $in: deleteIds } });
print(`Deleted AccountStatement rows: ${deleteResult.deletedCount ?? 0}`);

const rebuildReports = affectedUsers.map((userId) => rebuildBalanceChainForUser(userId));
rebuildReports.forEach((report) => {
  print(`Rebuilt balances for ${report.userId}: rowsUpdated=${report.rowsUpdated}, currentBalance=${report.currentBalance}`);
});

const remaining = database.AccountStatement.find({
  tradeId: { $in: mirrorTradeIdList },
  entryType: { $in: TRADER_MIRROR_STMT_TYPES },
}).toArray().filter((row) => isPhantomTraderMirrorStatement(row, traderIdByMirrorTradeId)).length;
print(`Remaining phantom rows: ${remaining}`);
print('--- Done ---');
