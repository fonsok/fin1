'use strict';

const { syncTradeHasPoolParticipation } = require('../../utils/poolParticipationTradeSync');
const { countTraderPartialSellEvents } = require('../../utils/configHelper/traderPartialSellLimits');
const {
  buildInvestmentSearchBlob,
  buildTradeSearchBlob,
} = require('../../utils/adminListSearch');

/**
 * Maintenance: Trade summary flags + adminSearchBlob; optional Investment adminSearchBlob.
 * Params: limit, skip, entity ('trade' | 'investment').
 */
async function handleBackfillTradeSummaryFlags(request) {
  const {
    limit: limitRaw,
    skip: skipRaw,
    entity = 'trade',
  } = request.params || {};
  const limit = Math.min(500, Math.max(1, parseInt(limitRaw, 10) || 100));
  const skip = Math.max(0, parseInt(skipRaw, 10) || 0);

  if (entity === 'investment') {
    const q = new Parse.Query('Investment');
    q.ascending('createdAt');
    q.skip(skip);
    q.limit(limit);
    const rows = await q.find({ useMasterKey: true });
    const toSave = [];
    for (const inv of rows) {
      const blob = buildInvestmentSearchBlob(inv);
      if (inv.get('adminSearchBlob') !== blob) {
        inv.set('adminSearchBlob', blob);
        toSave.push(inv);
      }
    }
    if (toSave.length > 0) {
      await Parse.Object.saveAll(toSave, { useMasterKey: true });
    }
    return {
      entity: 'investment',
      processed: rows.length,
      updated: toSave.length,
      nextSkip: skip + rows.length,
      hasMore: rows.length === limit,
    };
  }

  const q = new Parse.Query('Trade');
  q.ascending('createdAt');
  q.skip(skip);
  q.limit(limit);
  const trades = await q.find({ useMasterKey: true });

  const toSave = [];
  for (const trade of trades) {
    // eslint-disable-next-line no-await-in-loop
    await syncTradeHasPoolParticipation(trade.id, true);
    const refreshed = await new Parse.Query('Trade').get(trade.id, { useMasterKey: true }).catch(() => trade);
    const count = countTraderPartialSellEvents(refreshed);
    const blob = buildTradeSearchBlob(refreshed);
    let dirty = false;
    if (refreshed.get('traderPartialSellEventCount') !== count) {
      refreshed.set('traderPartialSellEventCount', count);
      dirty = true;
    }
    if (refreshed.get('adminSearchBlob') !== blob) {
      refreshed.set('adminSearchBlob', blob);
      dirty = true;
    }
    if (dirty) toSave.push(refreshed);
  }
  if (toSave.length > 0) {
    await Parse.Object.saveAll(toSave, { useMasterKey: true });
  }

  return {
    entity: 'trade',
    processed: trades.length,
    updated: toSave.length,
    nextSkip: skip + trades.length,
    hasMore: trades.length === limit,
  };
}

module.exports = {
  handleBackfillTradeSummaryFlags,
};
