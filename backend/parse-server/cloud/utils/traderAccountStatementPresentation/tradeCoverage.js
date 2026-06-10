'use strict';

function tradeCoverageKeys(tradeId, tradeNumber) {
  const keys = [];
  if (tradeId) {
    const trimmed = String(tradeId).trim();
    if (trimmed) keys.push(`id:${trimmed}`);
  }
  if (tradeNumber !== undefined && tradeNumber !== null && tradeNumber !== '') {
    keys.push(`num:${tradeNumber}`);
  }
  return keys;
}

function markTradeCovered(set, tradeId, tradeNumber) {
  for (const key of tradeCoverageKeys(tradeId, tradeNumber)) {
    set.add(key);
  }
}

function isTradeCovered(set, tradeId, tradeNumber) {
  return tradeCoverageKeys(tradeId, tradeNumber).some((key) => set.has(key));
}

module.exports = {
  tradeCoverageKeys,
  markTradeCovered,
  isTradeCovered,
};
