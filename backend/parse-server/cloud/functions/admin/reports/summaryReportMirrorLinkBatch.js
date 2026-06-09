'use strict';

const {
  resolvePairedLegContextsByTradeId,
  loadTradesById,
} = require('./summaryReportPairedLegResolver');

async function resolvePairedLegContextsForRows(tradeRows, options = {}) {
  if (options.pairedLegContexts) return options.pairedLegContexts;
  return resolvePairedLegContextsByTradeId(tradeRows);
}

/**
 * Zeilen, denen nach enrich noch ein Pool-Mirror fehlt (Trader-/Standalone-Leg).
 */
function collectTraderRowsNeedingMirrorLink(enrichedItems, tradeRows, contexts) {
  const mirrorTradeIds = new Set();
  const rowIndices = [];

  for (let i = 0; i < tradeRows.length; i += 1) {
    if (enrichedItems[i].poolMirrorTrade) continue;
    if (enrichedItems[i].legKind !== 'trader' && enrichedItems[i].legKind !== 'standalone') continue;

    const ctx = contexts.get(tradeRows[i].id);
    const mirrorId = ctx?.mirrorTradeId;
    if (!mirrorId || mirrorId === tradeRows[i].id) continue;

    mirrorTradeIds.add(mirrorId);
    rowIndices.push(i);
  }

  return { mirrorTradeIds, rowIndices };
}

/**
 * Zeilen mit Pool-Snapshot aber ohne Trader-Leg (Mirror-Pool-Zeile in der Liste).
 */
function collectPoolRowsNeedingTraderLink(enrichedItems, tradeRows, contexts) {
  const traderTradeIds = new Set();
  const rowIndices = [];

  for (let i = 0; i < tradeRows.length; i += 1) {
    if (enrichedItems[i].traderTrade) continue;
    if (!enrichedItems[i].poolMirrorTrade) continue;

    const ctx = contexts.get(tradeRows[i].id);
    const traderId = ctx?.traderTradeId;
    if (!traderId || traderId === tradeRows[i].id) continue;

    traderTradeIds.add(traderId);
    rowIndices.push(i);
  }

  return { traderTradeIds, rowIndices };
}

async function loadTradesByIdMap(tradeIds) {
  return loadTradesById([...tradeIds]);
}

module.exports = {
  resolvePairedLegContextsForRows,
  collectTraderRowsNeedingMirrorLink,
  collectPoolRowsNeedingTraderLink,
  loadTradesByIdMap,
};
