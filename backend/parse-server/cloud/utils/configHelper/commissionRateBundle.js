'use strict';

const { validateConfigValue, validateInvestorCommissionRateTotalMatch } = require('./validateConfigValue');

const COMMISSION_RATE_KEYS = [
  'investorCommissionRateTotal',
  'traderCommissionRate',
  'appCommissionRate',
];

const COMMISSION_RATE_BUNDLE_PARAMETER_NAME = 'commissionRateBundle';

function roundRate(n) {
  return Math.round(Number(n) * 10000) / 10000;
}

function normalizeCommissionRateBundle(raw) {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const investorCommissionRateTotal = roundRate(raw.investorCommissionRateTotal);
  const traderCommissionRate = roundRate(raw.traderCommissionRate);
  const appCommissionRate = roundRate(raw.appCommissionRate);
  if (
    !Number.isFinite(investorCommissionRateTotal)
    || !Number.isFinite(traderCommissionRate)
    || !Number.isFinite(appCommissionRate)
  ) {
    return null;
  }
  return {
    investorCommissionRateTotal,
    traderCommissionRate,
    appCommissionRate,
  };
}

function validateCommissionRateBundle(bundle) {
  const normalized = normalizeCommissionRateBundle(bundle);
  if (!normalized) {
    return { valid: false, error: 'Ungültiges Provisions-Bundle (investorCommissionRateTotal, traderCommissionRate, appCommissionRate erforderlich).' };
  }

  for (const key of COMMISSION_RATE_KEYS) {
    const validation = validateConfigValue(key, normalized[key]);
    if (!validation.valid) {
      return { valid: false, error: validation.error };
    }
  }

  const sumCheck = validateInvestorCommissionRateTotalMatch(
    'investorCommissionRateTotal',
    normalized.investorCommissionRateTotal,
    {
      investorCommissionRateTotal: normalized.investorCommissionRateTotal,
      traderCommissionRate: normalized.traderCommissionRate,
      appCommissionRate: normalized.appCommissionRate,
    },
  );
  if (!sumCheck.valid) {
    return sumCheck;
  }

  return { valid: true, bundle: normalized };
}

function formatCommissionRateBundle(bundle) {
  const normalized = normalizeCommissionRateBundle(bundle);
  if (!normalized) {
    return String(bundle);
  }
  const pct = (rate) => `${(roundRate(rate) * 100).toFixed(1).replace(/\.0$/, '')} %`;
  return `${pct(normalized.investorCommissionRateTotal)} gesamt (Trader ${pct(normalized.traderCommissionRate)} · App ${pct(normalized.appCommissionRate)})`;
}

function extractCommissionRateBundleFromConfig(config) {
  const financial = config?.financial ?? config ?? {};
  return normalizeCommissionRateBundle({
    investorCommissionRateTotal: financial.investorCommissionRateTotal,
    traderCommissionRate: financial.traderCommissionRate,
    appCommissionRate: financial.appCommissionRate,
  });
}

module.exports = {
  COMMISSION_RATE_KEYS,
  COMMISSION_RATE_BUNDLE_PARAMETER_NAME,
  normalizeCommissionRateBundle,
  validateCommissionRateBundle,
  formatCommissionRateBundle,
  extractCommissionRateBundleFromConfig,
};
