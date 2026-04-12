'use strict';

const { loadConfig } = require('./configHelper/index.js');

function formatEuroDe(n) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

/**
 * Authoritative validation of a single investment principal amount (EUR)
 * against admin Configuration limits. Used by Cloud Functions and beforeSave.
 *
 * @param {number|string} amount
 * @returns {Promise<{ valid: boolean, error?: string }>}
 */
async function validateInvestmentAmountAgainstLimits(amount) {
  const config = await loadConfig(true);
  const minInv = Number(config.limits?.minInvestment);
  const maxInv = Number(config.limits?.maxInvestment);
  const minOk = Number.isFinite(minInv) && minInv > 0 ? minInv : 20.0;
  const maxOk = Number.isFinite(maxInv) && maxInv > 0 ? maxInv : 100000.0;
  const lo = Math.min(minOk, maxOk);
  const hi = Math.max(minOk, maxOk);

  const a = Number(amount);
  if (!Number.isFinite(a) || a <= 0) {
    return { valid: false, error: 'Der Anlagebetrag muss größer als null sein.' };
  }
  const rounded = Math.round(a * 100) / 100;
  if (rounded < lo) {
    return {
      valid: false,
      error: `Der Anlagebetrag muss mindestens ${formatEuroDe(lo)} betragen (administratives Minimum).`,
    };
  }
  if (rounded > hi) {
    return {
      valid: false,
      error: `Der Anlagebetrag darf höchstens ${formatEuroDe(hi)} betragen (administratives Maximum je Investment).`,
    };
  }
  return { valid: true };
}

module.exports = { validateInvestmentAmountAgainstLimits };
