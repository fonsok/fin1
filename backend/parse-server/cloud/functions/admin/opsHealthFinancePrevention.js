'use strict';

/** Must match `backend/scripts/ensure-finance-integrity-indexes.js` index names. */
const REQUIRED_ACCOUNT_STATEMENT_UNIQUE_INDEXES = [
  'AccountStatement_backend_trade_buy_user_tradeId_unique',
  'AccountStatement_backend_trade_buy_user_businessCase_unique',
  'AccountStatement_backend_trade_buy_user_tradeNumber_unique',
  'AccountStatement_backend_trade_sell_user_referenceDocument_unique',
];

const OPS_HEALTH_SNAPSHOT_INDEX = 'OpsHealthSnapshot_kind_runAt';

async function listCollectionIndexNames(collection) {
  const uri = process.env.PARSE_SERVER_DATABASE_URI;
  if (!uri || !String(uri).trim()) {
    return { ok: false, error: 'PARSE_SERVER_DATABASE_URI missing', names: [] };
  }

  const { MongoClient } = require('mongodb');
  const client = new MongoClient(String(uri).trim(), { maxPoolSize: 2 });
  await client.connect();
  try {
    const indexes = await client.db().collection(collection).indexes();
    return {
      ok: true,
      names: indexes.map((index) => String(index.name || '')),
      indexes: indexes.map((index) => ({
        name: index.name,
        unique: Boolean(index.unique),
        key: index.key,
      })),
    };
  } finally {
    await client.close();
  }
}

async function handleGetFinanceIntegrityPreventionStatus() {
  const accountStatement = await listCollectionIndexNames('AccountStatement');
  const opsSnapshot = await listCollectionIndexNames('OpsHealthSnapshot');

  const present = new Set(accountStatement.ok ? accountStatement.names : []);
  const missingIndexes = REQUIRED_ACCOUNT_STATEMENT_UNIQUE_INDEXES.filter((name) => !present.has(name));
  const hasOpsSnapshotIndex = opsSnapshot.ok
    && opsSnapshot.names.includes(OPS_HEALTH_SNAPSHOT_INDEX);

  let overall = 'healthy';
  if (!accountStatement.ok) {
    overall = 'unknown';
  } else if (missingIndexes.length > 0) {
    overall = 'degraded';
  }

  return {
    overall,
    layer: 'prevention',
    accountStatementIndexes: {
      ok: accountStatement.ok,
      error: accountStatement.error || null,
      required: REQUIRED_ACCOUNT_STATEMENT_UNIQUE_INDEXES,
      missing: missingIndexes,
      present: REQUIRED_ACCOUNT_STATEMENT_UNIQUE_INDEXES.filter((name) => present.has(name)),
    },
    opsHealthSnapshotIndex: {
      required: OPS_HEALTH_SNAPSHOT_INDEX,
      present: hasOpsSnapshotIndex,
    },
    repairHint: missingIndexes.length > 0
      ? 'mongosh fin1 backend/scripts/ensure-finance-integrity-indexes.js (repair duplicates first if SKIP)'
      : null,
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  REQUIRED_ACCOUNT_STATEMENT_UNIQUE_INDEXES,
  handleGetFinanceIntegrityPreventionStatus,
  listCollectionIndexNames,
};
