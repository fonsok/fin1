// Idempotent index creation for paired-execution + pool activation hot paths.
// Run on existing deployments: mongosh fin1 ensure-paired-execution-indexes.js
// (or via docker exec into mongo container)

db = db.getSiblingDB('fin1');

print('=== Paired execution / pool activation indexes ===');

db.Order.createIndex({ pairExecutionId: 1 }, { sparse: true, name: 'Order_pairExecutionId' });
db.Order.createIndex({ pairExecutionId: 1, legType: 1 }, { sparse: true, name: 'Order_pairExecutionId_legType' });
db.Order.createIndex({ clientOrderIntentId: 1 }, { sparse: true, name: 'Order_clientOrderIntentId' });

db.PairedExecution.createIndex(
  { traderId: 1, clientOrderIntentId: 1 },
  { unique: true, sparse: true, name: 'PairedExecution_trader_intent' },
);
db.PairedExecution.createIndex({ traderId: 1, status: 1 }, { name: 'PairedExecution_trader_status' });
db.PairedExecution.createIndex({ status: 1, effectsApplied: 1 }, { name: 'PairedExecution_status_effects' });

db.PoolTradeParticipation.createIndex(
  { investmentId: 1, isSettled: 1 },
  { name: 'PoolTradeParticipation_investmentId_isSettled' },
);
db.PoolTradeParticipation.createIndex(
  { tradeId: 1, isSettled: 1 },
  { name: 'PoolTradeParticipation_tradeId_isSettled' },
);

print('Done.');
