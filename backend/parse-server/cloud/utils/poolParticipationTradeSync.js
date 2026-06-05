'use strict';

const SYNC_CACHE_MS = 60_000;
const syncCache = new Map();

/**
 * Denormalized `Trade.hasPoolParticipation` — O(1) filter for Summary Report / admin lists.
 * @param {string} tradeId
 * @param {boolean} [force]
 */
async function syncTradeHasPoolParticipation(tradeId, force = false) {
  const tid = String(tradeId || '').trim();
  if (!tid) return;

  const now = Date.now();
  if (!force) {
    const hit = syncCache.get(tid);
    if (hit && now - hit.at < SYNC_CACHE_MS) return;
  }

  const count = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tid)
    .count({ useMasterKey: true });

  const trade = await new Parse.Query('Trade').get(tid, { useMasterKey: true }).catch(() => null);
  if (!trade) return;

  const hasPool = count > 0;
  if (trade.get('hasPoolParticipation') === hasPool) {
    syncCache.set(tid, { at: now, hasPool });
    return;
  }

  trade.set('hasPoolParticipation', hasPool);
  await trade.save(null, { useMasterKey: true });
  syncCache.set(tid, { at: now, hasPool });
}

function invalidatePoolParticipationSyncCache(tradeId) {
  if (tradeId) syncCache.delete(String(tradeId).trim());
  else syncCache.clear();
}

module.exports = {
  syncTradeHasPoolParticipation,
  invalidatePoolParticipationSyncCache,
};
