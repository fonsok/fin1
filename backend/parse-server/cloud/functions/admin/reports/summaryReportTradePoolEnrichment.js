'use strict';

const { loadConfig, getTraderCommissionRate } = require('../../../utils/configHelper/index.js');
const {
  buildPartialSellEvents,
  resolveTraderParseTradeForRow,
  resolvePoolParseTradeForRow,
} = require('./summaryReportPartialSellEvents');
const {
  getMirrorTradeForPairedTraderLeg,
  getTraderTradeForPairedMirrorLeg,
} = require('../../../utils/pairedTradeMirrorSync');
const {
  collectTradeIdsFromDraftRows,
  loadDocumentsByTradeIds,
  attachBelegeToSummaryRows,
} = require('./summaryReportTradeBelege');
const { resolveLegReturnPercentage } = require('../../../utils/accountingHelper/legPriceMetrics');
const { tradeEconomicsSnapshot } = require('../../../utils/poolMirrorEconomics/tradeLegEconomics');
const {
  resolvePairedLegContextsByTradeId,
  loadTradesById,
  resolveTraderAndPoolObjects,
  resolvePoolParticipationsForRow,
  applyPoolMirrorFromParticipations,
} = require('./summaryReportPairedLegResolver');
const {
  loadParticipationsByPoolTradeIds,
  enrichParticipationDisplayFields,
} = require('./summaryReportParticipationLoader');

async function enrichSummaryReportTrades(tradeRows, baseItems) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const snapshotOptions = { feeConfig };

  const contexts = await resolvePairedLegContextsByTradeId(tradeRows);

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

    let resolved = resolveTraderAndPoolObjects(trade, ctx, tradeById);
    const { poolTradeId: effectivePoolId, participations } = resolvePoolParticipationsForRow(trade, ctx, participationsByPool);
    resolved = applyPoolMirrorFromParticipations({
      tradeRow: trade, legKind: resolved.legKind, traderTrade: resolved.traderTrade,
      poolMirrorTrade: resolved.poolMirrorTrade, poolTradeId: effectivePoolId,
      participations, tradeById, feeConfig,
    });

    if (resolved.poolMirrorTrade?.tradeId === trade.id) {
      resolved.legKind = 'mirror_pool';
      if (!resolved.traderTrade) resolved.traderTrade = null;
    } else if (!resolved.traderTrade) {
      resolved.traderTrade = tradeEconomicsSnapshot(trade, null, snapshotOptions);
    } else if (resolved.legKind === 'trader' && resolved.traderTrade.tradeId !== trade.id) {
      resolved.traderTrade = tradeEconomicsSnapshot(trade, null, snapshotOptions);
    }

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

async function ensureMirrorLinkForTraderRows(enrichedItems, tradeRows) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const snapshotOptions = { feeConfig };

  const out = [...enrichedItems];
  for (let i = 0; i < tradeRows.length; i += 1) {
    if (out[i].poolMirrorTrade) continue;
    if (out[i].legKind !== 'trader' && out[i].legKind !== 'standalone') continue;
    const mirror = await getMirrorTradeForPairedTraderLeg(tradeRows[i]);
    if (!mirror || mirror.id === tradeRows[i].id) continue;
    const parts = await loadParticipationsByPoolTradeIds([mirror.id]);
    const traderSnap = out[i].traderTrade || tradeEconomicsSnapshot(tradeRows[i], null, snapshotOptions);
    const snap = tradeEconomicsSnapshot(mirror, parts.get(mirror.id) || [], {
      traderReference: traderSnap, applyPoolMirror: true, feeConfig,
    });
    const docsByTradeId = await loadDocumentsByTradeIds([mirror.id, tradeRows[i].id]);
    const [withBelege] = attachBelegeToSummaryRows(
      [{
        ...out[i], legKind: 'trader', poolTradeId: mirror.id,
        traderTrade: traderSnap, poolMirrorTrade: snap, linkedTraderTrade: traderSnap,
        poolParticipations: parts.get(mirror.id) || out[i].poolParticipations,
      }],
      docsByTradeId,
    );
    out[i] = { ...withBelege, hasPoolDetails: true };
  }
  return out;
}

async function ensureTraderLinkForPoolRows(enrichedItems, tradeRows) {
  const out = [...enrichedItems];
  for (let i = 0; i < tradeRows.length; i += 1) {
    if (out[i].traderTrade) continue;
    if (!out[i].poolMirrorTrade) continue;
    const trader = await getTraderTradeForPairedMirrorLeg(tradeRows[i]);
    if (!trader) continue;
    const traderSnap = tradeEconomicsSnapshot(trader);
    out[i] = { ...out[i], legKind: 'mirror_pool', traderTrade: traderSnap, linkedTraderTrade: traderSnap };
  }
  return out;
}

module.exports = {
  enrichSummaryReportTrades,
  attachPartialSellEventsToSummaryRows,
  ensureMirrorLinkForTraderRows,
  ensureTraderLinkForPoolRows,
  tradeEconomicsSnapshot,
  resolvePairedLegContextsByTradeId,
};
