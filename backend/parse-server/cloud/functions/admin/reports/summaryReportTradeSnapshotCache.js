'use strict';

const { tradeEconomicsSnapshot } = require('../../../utils/poolMirrorEconomics/tradeLegEconomics');
const { applyPoolMirrorEconomicsToSnapshot } = require('../../../utils/poolMirrorEconomics');

function participationCacheKey(participations) {
  if (!Array.isArray(participations) || participations.length === 0) return '';
  return participations
    .map((p) => `${p.investmentId || ''}:${Number(p.investmentCapital || 0)}`)
    .sort()
    .join('|');
}

/**
 * Request-scoped cache: max. ein tradeEconomicsSnapshot pro tradeId / Pool-Kontext.
 */
function createTradeLegSnapshotCache(feeConfig = {}) {
  const options = { feeConfig };
  const legSnapByTradeId = new Map();
  const poolMirrorByKey = new Map();
  const poolSellSyncByKey = new Map();
  let legSnapBuildCount = 0;
  let poolMirrorBuildCount = 0;

  function getLegSnap(tradeObj) {
    if (!tradeObj?.id) return null;
    if (!legSnapByTradeId.has(tradeObj.id)) {
      legSnapBuildCount += 1;
      legSnapByTradeId.set(tradeObj.id, tradeEconomicsSnapshot(tradeObj, null, options));
    }
    return legSnapByTradeId.get(tradeObj.id);
  }

  function getPoolMirrorSnap(poolObj, participations, traderReference) {
    if (!poolObj?.id || !participations?.length) return null;
    const key = `${poolObj.id}#${participationCacheKey(participations)}#${traderReference?.tradeId || ''}`;
    if (!poolMirrorByKey.has(key)) {
      poolMirrorBuildCount += 1;
      poolMirrorByKey.set(
        key,
        tradeEconomicsSnapshot(poolObj, participations, {
          ...options,
          traderReference,
          applyPoolMirror: true,
        }),
      );
    }
    return poolMirrorByKey.get(key);
  }

  function syncPoolMirrorSellOnly(poolMirrorSnap, traderReference, participations = []) {
    if (!poolMirrorSnap) return null;
    const key = [
      'sync',
      poolMirrorSnap.tradeId,
      traderReference?.tradeId || '',
      traderReference?.soldQuantity || 0,
      participationCacheKey(participations),
    ].join('#');
    if (!poolSellSyncByKey.has(key)) {
      poolSellSyncByKey.set(
        key,
        applyPoolMirrorEconomicsToSnapshot(poolMirrorSnap, traderReference, participations),
      );
    }
    return poolSellSyncByKey.get(key);
  }

  return {
    getLegSnap,
    getPoolMirrorSnap,
    syncPoolMirrorSellOnly,
    stats: () => ({ legSnapBuildCount, poolMirrorBuildCount }),
  };
}

module.exports = {
  createTradeLegSnapshotCache,
  participationCacheKey,
};
