'use strict';

const { DEFAULT_CONFIG } = require('./defaultConfig');
const { loadConfig } = require('./loadConfig');
const { validateConfigValue } = require('./validateConfigValue');

function formatEur(amount) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}

/**
 * Normalizes admin `minTraderBuyOrderAmount` (EUR gross on TRADER buy leg).
 * 0 = enforcement disabled.
 */
function normalizeMinTraderBuyOrderAmount(raw) {
  if (raw === null || raw === undefined) {
    return DEFAULT_CONFIG.limits.minTraderBuyOrderAmount ?? 300;
  }
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0) {
    return DEFAULT_CONFIG.limits.minTraderBuyOrderAmount ?? 300;
  }
  const validation = validateConfigValue('minTraderBuyOrderAmount', n);
  if (!validation.valid) {
    return DEFAULT_CONFIG.limits.minTraderBuyOrderAmount ?? 300;
  }
  return n;
}

async function getMinTraderBuyOrderAmount() {
  const config = await loadConfig();
  const raw = config.limits?.minTraderBuyOrderAmount
    ?? config.financial?.minTraderBuyOrderAmount;
  return normalizeMinTraderBuyOrderAmount(raw);
}

/**
 * Enforces minimum gross amount on the trader-owned buy leg only (not pool-mirror).
 * @param {number} traderGrossAmount - quantity × price (EUR)
 * @param {number} [minAmount] - when omitted, loads from config
 */
function assertTraderBuyOrderMeetsMinimum(traderGrossAmount, minAmount) {
  const min = Number(minAmount);
  if (!Number.isFinite(min) || min <= 0) {
    return;
  }
  const gross = Number(traderGrossAmount);
  if (!Number.isFinite(gross) || gross + 1e-6 < min) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Mindest-Kaufbetrag (Trader-Anteil): ${formatEur(min)}. `
      + `Aktuell: ${formatEur(Number.isFinite(gross) ? gross : 0)}.`,
    );
  }
}

module.exports = {
  normalizeMinTraderBuyOrderAmount,
  getMinTraderBuyOrderAmount,
  assertTraderBuyOrderMeetsMinimum,
};
