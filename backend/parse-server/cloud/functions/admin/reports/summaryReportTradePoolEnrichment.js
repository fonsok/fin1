'use strict';

const { loadConfig, getTraderCommissionRate } = require('../../../utils/configHelper/index.js');
const {
  buildPartialSellEvents,
  resolveTraderParseTradeForRow,
  resolvePoolParseTradeForRow,
} = require('./summaryReportPartialSellEvents');
const {
  collectTradeIdsFromDraftRows,
  loadDocumentsByTradeIds,
  attachBelegeToSummaryRows,
} = require('./summaryReportTradeBelege');
const {
  resolvePairedLegContextsForRows,
  collectTraderRowsNeedingMirrorLink,
  collectPoolRowsNeedingTraderLink,
  loadTradesByIdMap,
} = require('./summaryReportMirrorLinkBatch');
const { resolveLegReturnPercentage } = require('../../../utils/accountingHelper/legPriceMetrics');
const { createTradeLegSnapshotCache } = require('./summaryReportTradeSnapshotCache');
const {
  resolvePairedLegContextsByTradeId,
  loadTradesById,
  buildPairedLegSnapshotsForRow,
} = require('./summaryReportPairedLegResolver');
const {
  loadParticipationsByPoolTradeIds,
  enrichParticipationDisplayFields,
} = require('./summaryReportParticipationLoader');

async function enrichSummaryReportTrades(tradeRows, baseItems, options = {}) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const snapshotCache = createTradeLegSnapshotCache(feeConfig);

  const contexts = await resolvePairedLegContextsForRows(tradeRows, options);

  const extraTradeIds = new Set();
  for (const ctx of contexts.values()) {
    if (ctx.mirrorTradeId && !tradeRows.some((t) => t.id === ctx.mirrorTradeId)) {
      extraTradeIds.add(ctx.mirrorTradeId);
    }
    if (ctx.traderTradeId && !tradeRows.some((t) => t.id === ctx.traderTradeId)) {
      extraTradeIds.add(ctx.traderTradeId);
    }
  }

  const linkedTrades = await loadTradesById(Array.from(extraTradeIds));
  const tradeById = new Map(tradeRows.map((t) => [t.id, t]));
  for (const [id, t] of linkedTrades) tradeById.set(id, t);

  const poolTradeIds = new Set();
  for (const ctx of contexts.values()) {
    if (ctx.poolTradeId) poolTradeIds.add(ctx.poolTradeId);
    if (ctx.mirrorTradeId) poolTradeIds.add(ctx.mirrorTradeId);
  }
  for (const t of tradeRows) poolTradeIds.add(t.id);
  const participationsByPool = await loadParticipationsByPoolTradeIds([...poolTradeIds]);

  const draftItems = baseItems.map((item, idx) => {
    const trade = tradeRows[idx];
    const ctx = contexts.get(trade.id) || {
      legKind: 'standalone', poolTradeId: trade.id, traderTradeId: trade.id, mirrorTradeId: null, pairExecutionId: null,
    };

    const resolved = buildPairedLegSnapshotsForRow(
      trade,
      ctx,
      tradeById,
      participationsByPool,
      snapshotCache,
    );
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
  });

  const tradeIdsForBelege = collectTradeIdsFromDraftRows(draftItems);
  const docsByTradeId = await loadDocumentsByTradeIds(tradeIdsForBelege);
  const withBelege = attachBelegeToSummaryRows(draftItems, docsByTradeId);

  return withBelege.map((row) => {
    const costBasis = row.poolMirrorTrade?.costBasisPerShare || row.traderTrade?.costBasisPerShare || 0;
    const poolParticipations = enrichParticipationDisplayFields(row.poolParticipations || [], costBasis);
    return { ...row, poolParticipations };
  });
}

async function attachPartialSellEventsToSummaryRows(items, tradeRows) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const commissionRate = await getTraderCommissionRate();

  const tradeById = new Map(tradeRows.map((t) => [t.id, t]));
  const extraIds = new Set();
  for (const row of items) {
    const traderId = row.traderTrade?.tradeId || row.linkedTraderTrade?.tradeId;
    const poolId = row.poolMirrorTrade?.tradeId || row.poolTradeId;
    if (traderId && !tradeById.has(traderId)) extraIds.add(traderId);
    if (poolId && !tradeById.has(poolId)) extraIds.add(poolId);
  }
  const linked = await loadTradesById([...extraIds]);
  for (const [id, t] of linked) tradeById.set(id, t);

  return items.map((row, idx) => {
    const tradeRow = tradeRows[idx] || null;
    const traderParse = resolveTraderParseTradeForRow(row, tradeRow, tradeById);
    const poolParse = resolvePoolParseTradeForRow(row, tradeById);
    const partialSellEvents = buildPartialSellEvents({
      traderTrade: traderParse, poolTrade: poolParse,
      poolMirrorSnap: row.poolMirrorTrade, participations: row.poolParticipations || [],
      traderBelege: row.traderBelege, poolBelege: row.poolBelege, feeConfig, commissionRate,
    });
    return { ...row, partialSellEvents };
  });
}

async function ensureMirrorLinkForTraderRows(enrichedItems, tradeRows, feeConfig = {}, options = {}) {
  const snapshotCache = createTradeLegSnapshotCache(feeConfig);
  const contexts = await resolvePairedLegContextsForRows(tradeRows, options);
  const { mirrorTradeIds, rowIndices } = collectTraderRowsNeedingMirrorLink(
    enrichedItems,
    tradeRows,
    contexts,
  );

  if (!rowIndices.length) return [...enrichedItems];

  const mirrorsById = await loadTradesByIdMap(mirrorTradeIds);
  const participationsByPool = await loadParticipationsByPoolTradeIds([...mirrorTradeIds]);

  const docTradeIds = new Set();
  for (const i of rowIndices) {
    docTradeIds.add(tradeRows[i].id);
    const mirrorId = contexts.get(tradeRows[i].id)?.mirrorTradeId;
    if (mirrorId) docTradeIds.add(mirrorId);
  }
  const docsByTradeId = await loadDocumentsByTradeIds([...docTradeIds]);

  const out = [...enrichedItems];
  for (const i of rowIndices) {
    const mirrorId = contexts.get(tradeRows[i].id)?.mirrorTradeId;
    const mirror = mirrorId ? mirrorsById.get(mirrorId) : null;
    if (!mirror) continue;

    const traderSnap = out[i].traderTrade || snapshotCache.getLegSnap(tradeRows[i]);
    const snap = snapshotCache.getPoolMirrorSnap(
      mirror,
      participationsByPool.get(mirror.id) || [],
      traderSnap,
    );
    const [withBelege] = attachBelegeToSummaryRows(
      [{
        ...out[i],
        legKind: 'trader',
        poolTradeId: mirror.id,
        traderTrade: traderSnap,
        poolMirrorTrade: snap,
        linkedTraderTrade: traderSnap,
        poolParticipations: participationsByPool.get(mirror.id) || out[i].poolParticipations,
      }],
      docsByTradeId,
    );
    out[i] = { ...withBelege, hasPoolDetails: true };
  }
  return out;
}

async function ensureTraderLinkForPoolRows(enrichedItems, tradeRows, feeConfig = {}, options = {}) {
  const snapshotCache = createTradeLegSnapshotCache(feeConfig);
  const contexts = await resolvePairedLegContextsForRows(tradeRows, options);
  const { traderTradeIds, rowIndices } = collectPoolRowsNeedingTraderLink(
    enrichedItems,
    tradeRows,
    contexts,
  );

  if (!rowIndices.length) return [...enrichedItems];

  const tradersById = await loadTradesByIdMap(traderTradeIds);
  const out = [...enrichedItems];
  for (const i of rowIndices) {
    const traderId = contexts.get(tradeRows[i].id)?.traderTradeId;
    const trader = traderId ? tradersById.get(traderId) : null;
    if (!trader) continue;
    const traderSnap = snapshotCache.getLegSnap(trader);
    out[i] = {
      ...out[i],
      legKind: 'mirror_pool',
      traderTrade: traderSnap,
      linkedTraderTrade: traderSnap,
    };
  }
  return out;
}

module.exports = {
  enrichSummaryReportTrades,
  attachPartialSellEventsToSummaryRows,
  ensureMirrorLinkForTraderRows,
  ensureTraderLinkForPoolRows,
  resolvePairedLegContextsByTradeId,
};
