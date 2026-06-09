'use strict';

const {
  applyPoolMirrorEconomicsToSnapshot,
  reconcilePoolMirrorSnapshot,
} = require('../../../utils/poolMirrorEconomics');

function normalizeLegType(legType) {
  return String(legType || '').trim().toUpperCase();
}

/** Parse-Objekte + legKind — keine Snapshots. */
function resolveLegObjects(tradeRow, ctx, tradeById) {
  let legKind = ctx.legKind;
  const mirrorId = ctx.mirrorTradeId;
  const rowId = tradeRow.id;

  if (legKind === 'standalone' && mirrorId && mirrorId !== rowId) {
    legKind = 'trader';
  }

  let traderObj = null;
  let poolObj = null;

  if (legKind === 'mirror_pool') {
    traderObj = ctx.traderTradeId ? tradeById.get(ctx.traderTradeId) : null;
    poolObj = tradeRow;
  } else if (legKind === 'trader') {
    traderObj = tradeRow;
    poolObj = mirrorId ? tradeById.get(mirrorId) : null;
  } else if (mirrorId && mirrorId !== rowId) {
    traderObj = tradeRow;
    poolObj = tradeById.get(mirrorId);
    legKind = 'trader';
  } else {
    traderObj = tradeRow;
    poolObj = null;
  }

  return {
    legKind,
    traderObj,
    poolObj,
    poolTradeId: poolObj?.id || ctx.poolTradeId,
  };
}

function resolvePoolParticipationsForRow(tradeRow, ctx, participationsByPool) {
  const candidates = [
    ctx.poolTradeId,
    tradeRow.id,
    ctx.mirrorTradeId,
  ].filter(Boolean);
  for (const tid of candidates) {
    const parts = participationsByPool.get(tid);
    if (parts?.length) return { poolTradeId: tid, participations: parts };
  }
  return { poolTradeId: ctx.poolTradeId || tradeRow.id, participations: [] };
}

/**
 * Ein Snapshot-Aufruf pro Leg/Kontext (Phase 2.1 — Request-Cache).
 */
function buildPairedLegSnapshotsForRow(tradeRow, ctx, tradeById, participationsByPool, cache) {
  let { legKind, traderObj, poolObj } = resolveLegObjects(tradeRow, ctx, tradeById);
  const { poolTradeId: effectivePoolId, participations } = resolvePoolParticipationsForRow(
    tradeRow,
    ctx,
    participationsByPool,
  );

  const poolObjEffective =
    tradeById.get(effectivePoolId)
    || (effectivePoolId === tradeRow.id ? tradeRow : null)
    || poolObj;

  let traderTrade = null;
  if (legKind === 'mirror_pool') {
    traderTrade = traderObj ? cache.getLegSnap(traderObj) : null;
  } else {
    traderTrade = cache.getLegSnap(tradeRow);
  }

  let poolMirrorTrade = null;
  if (participations.length && poolObjEffective) {
    poolMirrorTrade = cache.getPoolMirrorSnap(poolObjEffective, participations, traderTrade);
    if (effectivePoolId === tradeRow.id) {
      legKind = 'mirror_pool';
      if (!traderTrade && traderObj) {
        traderTrade = cache.getLegSnap(traderObj);
      }
    }
  } else if (poolObj && poolObj.id !== tradeRow.id) {
    const basePool = cache.getLegSnap(poolObj);
    poolMirrorTrade = cache.syncPoolMirrorSellOnly(basePool, traderTrade, []);
  }

  return {
    legKind,
    traderTrade,
    poolMirrorTrade,
    poolTradeId: effectivePoolId,
    participations,
  };
}

/** @deprecated Nutze buildPairedLegSnapshotsForRow — behält API für Tests. */
function resolveTraderAndPoolObjects(tradeRow, ctx, tradeById, cache) {
  if (!cache) {
    const { createTradeLegSnapshotCache } = require('./summaryReportTradeSnapshotCache');
    cache = createTradeLegSnapshotCache();
  }
  const built = buildPairedLegSnapshotsForRow(tradeRow, ctx, tradeById, new Map(), cache);
  return {
    legKind: built.legKind,
    traderTrade: built.traderTrade,
    poolMirrorTrade: built.poolMirrorTrade,
    poolTradeId: built.poolTradeId,
  };
}

/** @deprecated Nutze buildPairedLegSnapshotsForRow. */
function applyPoolMirrorFromParticipations({
  tradeRow,
  legKind,
  traderTrade,
  poolMirrorTrade,
  poolTradeId,
  participations,
  tradeById,
  feeConfig = {},
  cache,
}) {
  if (!cache) {
    const { createTradeLegSnapshotCache } = require('./summaryReportTradeSnapshotCache');
    cache = createTradeLegSnapshotCache(feeConfig);
  }
  if (participations.length) {
    const poolObj =
      tradeById.get(poolTradeId)
      || (poolTradeId === tradeRow.id ? tradeRow : null);
    if (!poolObj) {
      return { legKind, traderTrade, poolMirrorTrade, poolTradeId };
    }
    const poolSnap = cache.getPoolMirrorSnap(poolObj, participations, traderTrade);
    let nextLeg = legKind;
    if (poolTradeId === tradeRow.id) {
      nextLeg = 'mirror_pool';
    }
    return {
      legKind: nextLeg,
      traderTrade,
      poolMirrorTrade: poolSnap,
      poolTradeId,
    };
  }
  const synced = cache.syncPoolMirrorSellOnly(poolMirrorTrade, traderTrade, []);
  return { legKind, traderTrade, poolMirrorTrade: synced, poolTradeId };
}

async function resolvePairedLegContextsByTradeId(tradeRows) {
  const out = new Map();
  const buyOrderIds = [...new Set(tradeRows.map((t) => t.get('buyOrderId')).filter(Boolean))];
  if (buyOrderIds.length === 0) {
    for (const t of tradeRows) {
      out.set(t.id, { legKind: 'standalone', pairExecutionId: null, traderTradeId: t.id, mirrorTradeId: null, poolTradeId: t.id });
    }
    return out;
  }

  const buyOrders = await new Parse.Query('Order')
    .containedIn('objectId', buyOrderIds).limit(buyOrderIds.length).find({ useMasterKey: true });
  const orderById = new Map(buyOrders.map((o) => [o.id, o]));

  const pairIds = new Set();
  for (const o of buyOrders) {
    const pid = o.get('pairExecutionId');
    if (pid) pairIds.add(String(pid));
  }

  const pairLegsByPairId = new Map();
  if (pairIds.size > 0) {
    const pairOrders = await new Parse.Query('Order')
      .containedIn('pairExecutionId', Array.from(pairIds))
      .limit(Math.min(5000, pairIds.size * 4)).find({ useMasterKey: true });
    for (const o of pairOrders) {
      const pid = String(o.get('pairExecutionId') || '');
      if (!pid) continue;
      if (!pairLegsByPairId.has(pid)) pairLegsByPairId.set(pid, { trader: null, mirror: null });
      const bucket = pairLegsByPairId.get(pid);
      const leg = normalizeLegType(o.get('legType'));
      if (leg === 'TRADER') bucket.trader = o;
      if (leg === 'MIRROR_POOL') bucket.mirror = o;
    }
  }

  for (const trade of tradeRows) {
    const buyOrderId = trade.get('buyOrderId');
    const order = buyOrderId ? orderById.get(buyOrderId) : null;
    const pairId = order?.get('pairExecutionId') ? String(order.get('pairExecutionId')) : null;
    const leg = normalizeLegType(order?.get('legType'));

    if (pairId && pairLegsByPairId.has(pairId)) {
      const { trader, mirror } = pairLegsByPairId.get(pairId);
      const traderTradeId = trader?.get('tradeId') || null;
      const mirrorTradeId = mirror?.get('tradeId') || null;
      const poolTradeId = mirrorTradeId || trade.id;

      let legKind;
      if (leg === 'TRADER' || trade.id === traderTradeId) legKind = 'trader';
      else if (leg === 'MIRROR_POOL' || trade.id === mirrorTradeId) legKind = 'mirror_pool';
      else legKind = mirrorTradeId && mirrorTradeId !== trade.id ? 'trader' : 'standalone';

      out.set(trade.id, { legKind, pairExecutionId: pairId, traderTradeId: traderTradeId || trade.id, mirrorTradeId, poolTradeId });
    } else {
      out.set(trade.id, { legKind: 'standalone', pairExecutionId: null, traderTradeId: trade.id, mirrorTradeId: null, poolTradeId: trade.id });
    }
  }

  return out;
}

async function loadTradesById(tradeIds) {
  const ids = [...new Set(tradeIds.filter(Boolean))];
  if (!ids.length) return new Map();
  const rows = await new Parse.Query('Trade')
    .containedIn('objectId', ids).limit(ids.length).find({ useMasterKey: true });
  return new Map(rows.map((t) => [t.id, t]));
}

module.exports = {
  resolvePairedLegContextsByTradeId,
  loadTradesById,
  resolveLegObjects,
  buildPairedLegSnapshotsForRow,
  resolveTraderAndPoolObjects,
  resolvePoolParticipationsForRow,
  applyPoolMirrorFromParticipations,
  applyPoolMirrorFromTraderReference: applyPoolMirrorEconomicsToSnapshot,
  reconcilePoolMirrorSoldFromTrader: reconcilePoolMirrorSnapshot,
};
