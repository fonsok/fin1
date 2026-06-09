'use strict';

const { resolveLegReturnPercentage } = require('../../../utils/accountingHelper/legPriceMetrics');
const { createTradeLegSnapshotCache } = require('./summaryReportTradeSnapshotCache');
const {
  resolvePairedLegContextsForRows,
  collectTraderRowsNeedingMirrorLink,
  collectPoolRowsNeedingTraderLink,
  loadTradesByIdMap,
} = require('./summaryReportMirrorLinkBatch');
const {
  loadTradesById,
  buildPairedLegSnapshotsForRow,
} = require('./summaryReportPairedLegResolver');
const { loadParticipationsByPoolTradeIds } = require('./summaryReportParticipationLoader');

function defaultRowContext(trade) {
  return {
    legKind: 'standalone',
    poolTradeId: trade.id,
    traderTradeId: trade.id,
    mirrorTradeId: null,
    pairExecutionId: null,
  };
}

/**
 * Einmaliges Laden: Kontexte, verknüpfte Trades, Participations, Snapshot-Cache.
 */
async function prepareSummaryReportTradeBundle(tradeRows, feeConfig = {}, options = {}) {
  const contexts = await resolvePairedLegContextsForRows(tradeRows, options);
  const snapshotCache = createTradeLegSnapshotCache(feeConfig);

  const pageTradeIds = new Set(tradeRows.map((t) => t.id));
  const linkedTradeIds = new Set();
  for (const ctx of contexts.values()) {
    if (ctx.mirrorTradeId && !pageTradeIds.has(ctx.mirrorTradeId)) {
      linkedTradeIds.add(ctx.mirrorTradeId);
    }
    if (ctx.traderTradeId && !pageTradeIds.has(ctx.traderTradeId)) {
      linkedTradeIds.add(ctx.traderTradeId);
    }
  }

  const linkedTrades = await loadTradesById([...linkedTradeIds]);
  const tradeById = new Map(tradeRows.map((t) => [t.id, t]));
  for (const [id, t] of linkedTrades) tradeById.set(id, t);

  const poolTradeIds = new Set();
  for (const ctx of contexts.values()) {
    if (ctx.poolTradeId) poolTradeIds.add(ctx.poolTradeId);
    if (ctx.mirrorTradeId) poolTradeIds.add(ctx.mirrorTradeId);
  }
  for (const t of tradeRows) poolTradeIds.add(t.id);

  const participationsByPool = await loadParticipationsByPoolTradeIds([...poolTradeIds]);

  return {
    contexts,
    snapshotCache,
    tradeById,
    participationsByPool,
    feeConfig,
  };
}

function mapResolvedToSummaryRow(item, trade, resolved, ctx) {
  const { participations } = resolved;
  const investorIdsFromPool = [...new Set(participations.map((p) => p.investorId).filter(Boolean))];
  const traderSnap = resolved.traderTrade;
  const buyAmount = traderSnap
    ? Number(traderSnap.totalBuyCost ?? traderSnap.buyAmount ?? 0)
    : item.buyAmount;
  const profit = traderSnap ? Number(traderSnap.profit ?? 0) : item.profit;
  const returnPercentage = traderSnap
    ? resolveLegReturnPercentage(buyAmount, profit)
    : item.returnPercentage;

  return {
    ...item,
    buyAmount,
    profit,
    returnPercentage,
    investorIds: investorIdsFromPool.length > 0 ? investorIdsFromPool : item.investorIds,
    legKind: resolved.legKind,
    pairExecutionId: ctx.pairExecutionId,
    poolTradeId: resolved.poolTradeId,
    traderTrade: traderSnap,
    poolMirrorTrade: resolved.poolMirrorTrade,
    linkedTraderTrade: resolved.legKind === 'mirror_pool' ? traderSnap : null,
    poolParticipations: participations,
    poolExecutionBelege: null,
    hasPoolDetails: Boolean(resolved.poolMirrorTrade || participations.length > 0),
  };
}

function buildSummaryRowFromBundle(item, trade, bundle) {
  const ctx = bundle.contexts.get(trade.id) || defaultRowContext(trade);
  const resolved = buildPairedLegSnapshotsForRow(
    trade,
    ctx,
    bundle.tradeById,
    bundle.participationsByPool,
    bundle.snapshotCache,
  );
  return mapResolvedToSummaryRow(item, trade, resolved, ctx);
}

/**
 * Fallback: Trader-Zeilen mit bekanntem Mirror-Kontext aber ohne Pool-Snapshot.
 */
async function applyMissingMirrorLinks(items, tradeRows, bundle) {
  const { mirrorTradeIds, rowIndices } = collectTraderRowsNeedingMirrorLink(
    items,
    tradeRows,
    bundle.contexts,
  );
  if (!rowIndices.length) return items;

  const missingMirrorIds = [...mirrorTradeIds].filter((id) => !bundle.tradeById.has(id));
  if (missingMirrorIds.length) {
    const extraMirrors = await loadTradesByIdMap(new Set(missingMirrorIds));
    for (const [id, t] of extraMirrors) bundle.tradeById.set(id, t);
  }

  const missingPoolIds = [...mirrorTradeIds].filter((id) => !bundle.participationsByPool.has(id));
  if (missingPoolIds.length) {
    const extraParts = await loadParticipationsByPoolTradeIds(missingPoolIds);
    for (const [id, parts] of extraParts) bundle.participationsByPool.set(id, parts);
  }

  for (const i of rowIndices) {
    const mirrorId = bundle.contexts.get(tradeRows[i].id)?.mirrorTradeId;
    const mirror = mirrorId ? bundle.tradeById.get(mirrorId) : null;
    if (!mirror) continue;

    const traderSnap = items[i].traderTrade || bundle.snapshotCache.getLegSnap(tradeRows[i]);
    const participations = bundle.participationsByPool.get(mirror.id) || [];
    const snap = bundle.snapshotCache.getPoolMirrorSnap(mirror, participations, traderSnap)
      || bundle.snapshotCache.syncPoolMirrorSellOnly(
        bundle.snapshotCache.getLegSnap(mirror),
        traderSnap,
        participations,
      );
    if (!snap) continue;

    items[i] = {
      ...items[i],
      legKind: 'trader',
      poolTradeId: mirror.id,
      traderTrade: traderSnap,
      poolMirrorTrade: snap,
      linkedTraderTrade: traderSnap,
      poolParticipations: participations.length ? participations : items[i].poolParticipations,
      hasPoolDetails: true,
    };
  }

  return items;
}

/**
 * Fallback: Pool-Zeilen mit Pool-Snapshot aber ohne Trader-Leg.
 */
async function applyMissingTraderLinks(items, tradeRows, bundle) {
  const { traderTradeIds, rowIndices } = collectPoolRowsNeedingTraderLink(
    items,
    tradeRows,
    bundle.contexts,
  );
  if (!rowIndices.length) return items;

  const missingTraderIds = [...traderTradeIds].filter((id) => !bundle.tradeById.has(id));
  if (missingTraderIds.length) {
    const extraTraders = await loadTradesByIdMap(new Set(missingTraderIds));
    for (const [id, t] of extraTraders) bundle.tradeById.set(id, t);
  }

  for (const i of rowIndices) {
    const traderId = bundle.contexts.get(tradeRows[i].id)?.traderTradeId;
    const trader = traderId ? bundle.tradeById.get(traderId) : null;
    if (!trader) continue;
    const traderSnap = bundle.snapshotCache.getLegSnap(trader);
    items[i] = {
      ...items[i],
      legKind: 'mirror_pool',
      traderTrade: traderSnap,
      linkedTraderTrade: traderSnap,
    };
  }

  return items;
}

module.exports = {
  defaultRowContext,
  prepareSummaryReportTradeBundle,
  mapResolvedToSummaryRow,
  buildSummaryRowFromBundle,
  applyMissingMirrorLinks,
  applyMissingTraderLinks,
};
