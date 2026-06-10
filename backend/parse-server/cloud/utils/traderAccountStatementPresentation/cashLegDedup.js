'use strict';

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

function traderCashLegDedupKey(row) {
  const entryType = row.get('entryType');
  const tradeNumber = row.get('tradeNumber');
  // Customer view: one buy/sell cash line per trade number (paired legs may duplicate tradeId).
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

  return [...passthrough, ...bestByKey.values()];
}

module.exports = {
  isTraderExecutionBelegNumber,
  belegRank,
  traderCashLegDedupKey,
  prefersTraderExecutionBeleg,
  deduplicatedTraderCashLegs,
};
