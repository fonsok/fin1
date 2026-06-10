'use strict';

const { round2 } = require('../accountingHelper/shared');
const { TRADE_CASH_ENTRY_TYPES } = require('./shared');

function isTraderExecutionBelegNumber(number) {
  const n = String(number || '');
  return n.startsWith('TSC') || n.startsWith('TBC') || n.startsWith('TFS');
}

function belegRank(number) {
  if (isTraderExecutionBelegNumber(number)) return 3;
  if (String(number).includes('-INV-')) return 1;
  return 2;
}

function sellDuplicateAnchorKey(row) {
  const amount = round2(Math.abs(Number(row.get('amount') || 0)));
  if (!(amount > 0)) return null;
  const tradeId = String(row.get('tradeId') || '').trim();
  if (tradeId) return `id:${tradeId}@${amount}`;
  const tradeNumber = row.get('tradeNumber');
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    return `num:${tradeNumber}@${amount}`;
  }
  return null;
}

function traderCashLegDedupKey(row) {
  const entryType = String(row.get('entryType') || '');

  // Partial sells: one customer line per TSC / stmt row — not per trade number.
  if (entryType === 'trade_sell') {
    const refNum = String(row.get('referenceDocumentNumber') || '').trim();
    if (isTraderExecutionBelegNumber(refNum)) {
      return `sell:beleg:${refNum}`;
    }
    const refId = String(row.get('referenceDocumentId') || '').trim();
    if (refId) return `sell:doc:${refId}`;
    if (row.id) return `sell:stmt:${row.id}`;
    return null;
  }

  // Buy: one line per trade number (paired mirror legs may duplicate tradeId).
  const tradeNumber = row.get('tradeNumber');
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    return `num:${tradeNumber}#${entryType}`;
  }
  const tradeId = row.get('tradeId');
  if (tradeId) {
    const trimmed = String(tradeId).trim();
    if (trimmed) return `${trimmed}#${entryType}`;
  }
  return null;
}

function prefersTraderExecutionBeleg(candidate, existing) {
  const candidateNumber = candidate.get('referenceDocumentNumber') || '';
  const existingNumber = existing.get('referenceDocumentNumber') || '';
  const candidateIsExecution = isTraderExecutionBelegNumber(candidateNumber);
  const existingIsExecution = isTraderExecutionBelegNumber(existingNumber);
  if (candidateIsExecution !== existingIsExecution) {
    return candidateIsExecution;
  }
  const candidateAt = candidate.get('createdAt') || new Date(0);
  const existingAt = existing.get('createdAt') || new Date(0);
  return candidateAt.getTime() > existingAt.getTime();
}

function suppressSellStmtDuplicatesWhereExecutionBelegExists(rows) {
  const sells = [];
  const rest = [];
  for (const row of rows) {
    if (String(row.get('entryType') || '') === 'trade_sell') sells.push(row);
    else rest.push(row);
  }

  const executionAnchors = new Set();
  for (const row of sells) {
    const refNum = String(row.get('referenceDocumentNumber') || '');
    if (!isTraderExecutionBelegNumber(refNum)) continue;
    const anchorKey = sellDuplicateAnchorKey(row);
    if (anchorKey) executionAnchors.add(anchorKey);
  }

  const keptSells = sells.filter((row) => {
    const refNum = String(row.get('referenceDocumentNumber') || '');
    if (isTraderExecutionBelegNumber(refNum)) return true;
    const anchorKey = sellDuplicateAnchorKey(row);
    if (!anchorKey) return true;
    return !executionAnchors.has(anchorKey);
  });

  return [...rest, ...keptSells];
}

function deduplicatedTraderCashLegs(rows) {
  const passthrough = [];
  const bestByKey = new Map();

  for (const row of rows) {
    if (!TRADE_CASH_ENTRY_TYPES.has(String(row.get('entryType') || ''))) {
      passthrough.push(row);
      continue;
    }
    const key = traderCashLegDedupKey(row);
    if (!key) {
      passthrough.push(row);
      continue;
    }
    const existing = bestByKey.get(key);
    if (!existing || prefersTraderExecutionBeleg(row, existing)) {
      bestByKey.set(key, row);
    }
  }

  return suppressSellStmtDuplicatesWhereExecutionBelegExists([
    ...passthrough,
    ...bestByKey.values(),
  ]);
}

module.exports = {
  isTraderExecutionBelegNumber,
  belegRank,
  sellDuplicateAnchorKey,
  traderCashLegDedupKey,
  prefersTraderExecutionBeleg,
  suppressSellStmtDuplicatesWhereExecutionBelegExists,
  deduplicatedTraderCashLegs,
};
