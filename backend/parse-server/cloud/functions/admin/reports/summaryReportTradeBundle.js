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
const { loadParticipationsBundleForSummaryReport } = require('./summaryReportParticipationLoader');

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

  const participationBundle = await loadParticipationsBundleForSummaryReport([...poolTradeIds]);

  return {
    contexts,
    snapshotCache,
    tradeById,
    participationsByPool: participationBundle.participationsByPool,
    participationCountsByPool: participationBundle.participationCountsByPool,
    participationAggregatesByPool: participationBundle.participationAggregatesByPool,
    participationsInlineMax: participationBundle.inlineMax,
    feeConfig,
  };
}

function mapResolvedToSummaryRow(item, trade, resolved, ctx, bundleMeta = {}) {
  const { participations } = resolved;
  const poolTradeId = resolved.poolTradeId || ctx.poolTradeId || null;
  const participationTotal = poolTradeId
    ? (bundleMeta.participationCountsByPool?.get(poolTradeId) ?? participations.length)
    : participations.length;
  const aggregates = poolTradeId
    ? bundleMeta.participationAggregatesByPool?.get(poolTradeId)
    : null;
  const inlineMax = bundleMeta.participationsInlineMax ?? participationTotal;
  const participationsTruncated = participationTotal > inlineMax;
  const investorIdsFromPool = participationsTruncated
    ? []
    : [...new Set(participations.map((p) => p.investorId).filter(Boolean))];
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
    poolParticipations: participationsTruncated ? [] : participations,
    poolParticipationsTotal: participationTotal,
    poolParticipationsTruncated: participationsTruncated,
    poolParticipationsPoolTradeId: poolTradeId,
    poolParticipationsAggregates: aggregates
      ? {
        totalCommission: aggregates.totalCommission,
        totalProfitShare: aggregates.totalProfitShare,
      }
      : null,
    poolExecutionBelege: null,
    hasPoolDetails: Boolean(resolved.poolMirrorTrade || participationTotal > 0),
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
    bundle.participationCountsByPool,
  );
  return mapResolvedToSummaryRow(item, trade, resolved, ctx, {
    participationCountsByPool: bundle.participationCountsByPool,
    participationAggregatesByPool: bundle.participationAggregatesByPool,
    participationsInlineMax: bundle.participationsInlineMax,
  });
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
    const { loadParticipationsBundleForSummaryReport } = require('./summaryReportParticipationLoader');
    const extraBundle = await loadParticipationsBundleForSummaryReport(missingPoolIds);
    for (const [id, parts] of extraBundle.participationsByPool) {
      bundle.participationsByPool.set(id, parts);
    }
    for (const [id, count] of extraBundle.participationCountsByPool) {
      bundle.participationCountsByPool.set(id, count);
    }
    for (const [id, agg] of extraBundle.participationAggregatesByPool) {
      bundle.participationAggregatesByPool.set(id, agg);
    }
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

    const participationTotal = bundle.participationCountsByPool.get(mirror.id)
      ?? participations.length;
    const participationsTruncated = participationTotal > bundle.participationsInlineMax;
    items[i] = {
      ...items[i],
      legKind: 'trader',
      poolTradeId: mirror.id,
      traderTrade: traderSnap,
      poolMirrorTrade: snap,
      linkedTraderTrade: traderSnap,
      poolParticipations: participationsTruncated ? [] : (participations.length ? participations : items[i].poolParticipations),
      poolParticipationsTotal: participationTotal,
      poolParticipationsTruncated: participationsTruncated,
      poolParticipationsPoolTradeId: mirror.id,
      poolParticipationsAggregates: bundle.participationAggregatesByPool.get(mirror.id) || null,
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
