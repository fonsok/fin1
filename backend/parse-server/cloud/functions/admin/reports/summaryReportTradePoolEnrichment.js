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
  prepareSummaryReportTradeBundle,
  buildSummaryRowFromBundle,
  applyMissingMirrorLinks,
  applyMissingTraderLinks,
} = require('./summaryReportTradeBundle');
const {
  resolvePairedLegContextsByTradeId,
  loadTradesById,
} = require('./summaryReportPairedLegResolver');
const { enrichParticipationDisplayFields } = require('./summaryReportParticipationLoader');

async function enrichSummaryReportTrades(tradeRows, baseItems, options = {}) {
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const bundle = await prepareSummaryReportTradeBundle(tradeRows, feeConfig, options);

  let items = baseItems.map((item, idx) =>
    buildSummaryRowFromBundle(item, tradeRows[idx], bundle),
  );

  await applyMissingMirrorLinks(items, tradeRows, bundle);
  await applyMissingTraderLinks(items, tradeRows, bundle);

  const docsByTradeId = await loadDocumentsByTradeIds(collectTradeIdsFromDraftRows(items));
  const withBelege = attachBelegeToSummaryRows(items, docsByTradeId);

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

module.exports = {
  enrichSummaryReportTrades,
  attachPartialSellEventsToSummaryRows,
  resolvePairedLegContextsByTradeId,
};
