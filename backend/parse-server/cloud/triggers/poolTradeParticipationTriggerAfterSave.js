'use strict';

const { syncTradeHasPoolParticipation, invalidatePoolParticipationSyncCache } = require('../utils/poolParticipationTradeSync');

Parse.Cloud.afterSave('PoolTradeParticipation', async (request) => {
  const tradeId = request.object.get('tradeId');
  invalidatePoolParticipationSyncCache(tradeId);
  await syncTradeHasPoolParticipation(tradeId, true);
});

Parse.Cloud.afterDelete('PoolTradeParticipation', async (request) => {
  const tradeId = request.object.get('tradeId');
  invalidatePoolParticipationSyncCache(tradeId);
  await syncTradeHasPoolParticipation(tradeId, true);
});
