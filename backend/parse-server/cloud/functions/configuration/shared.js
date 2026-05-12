'use strict';

const { invalidateCache, TRANSACTION_LIMIT_SNAKE_TO_CAMEL } = require('../../utils/configHelper/index.js');
const { normalizeTaxCollectionMode } = require('../../utils/configHelper/taxCollectionMode');
const TAX_CONFIG_KEYS = new Set([
  'withholdingTaxRate',
  'solidaritySurchargeRate',
  'vatRate',
  'taxCollectionMode',
]);

function formatValue(value) {
  if (typeof value === 'number') {
    if (value < 1) {
      return `${(value * 100).toFixed(1)}%`;
    }
    return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(value);
  }
  return String(value);
}

function getOldValueFromConfig(config, parameterName) {
  const limitCamel = TRANSACTION_LIMIT_SNAKE_TO_CAMEL[parameterName];
  if (limitCamel) {
    return config.limits[limitCamel]
      ?? config.limits[parameterName]
      ?? config.financial[parameterName];
  }
  return config.financial[parameterName]
    ?? config.tax?.[parameterName]
    ?? (parameterName === 'legalAppName' ? config.legal?.appName : undefined)
    ?? config.limits[parameterName]
    ?? config.display[parameterName];
}

function buildDisplay(config) {
  const fallbackWalletEnabled = config.display?.walletFeatureEnabled ?? false;
  const walletActionModeGlobal = typeof config.display?.walletActionModeGlobal === 'string'
    ? config.display.walletActionModeGlobal
    : (
      typeof config.display?.walletActionMode === 'string'
        ? config.display.walletActionMode
        : (fallbackWalletEnabled ? 'deposit_and_withdrawal' : 'disabled')
    );
  const walletActionModeInvestor = typeof config.display?.walletActionModeInvestor === 'string'
    ? config.display.walletActionModeInvestor
    : 'deposit_and_withdrawal';
  const walletActionModeTrader = typeof config.display?.walletActionModeTrader === 'string'
    ? config.display.walletActionModeTrader
    : 'deposit_and_withdrawal';
  const walletActionModeIndividual = typeof config.display?.walletActionModeIndividual === 'string'
    ? config.display.walletActionModeIndividual
    : 'deposit_and_withdrawal';
  const walletActionModeCompany = typeof config.display?.walletActionModeCompany === 'string'
    ? config.display.walletActionModeCompany
    : 'deposit_and_withdrawal';
  return {
    showCommissionBreakdownInCreditNote: config.display?.showCommissionBreakdownInCreditNote ?? true,
    showDocumentReferenceLinksInAccountStatement: config.display?.showDocumentReferenceLinksInAccountStatement ?? true,
    maximumRiskExposurePercent: config.display?.maximumRiskExposurePercent ?? 2.0,
    walletActionModeGlobal,
    walletActionModeInvestor,
    walletActionModeTrader,
    walletActionModeIndividual,
    walletActionModeCompany,
    // Keep legacy field to avoid older clients breaking.
    walletActionMode: walletActionModeGlobal,
    walletFeatureEnabled: fallbackWalletEnabled,
    // ADR-007 Phase 2 rollout flag: default false so legacy clients keep the local Invoice path.
    serviceChargeInvoiceFromBackend: config.display?.serviceChargeInvoiceFromBackend ?? false,
    serviceChargeLegacyClientFallbackEnabled:
      config.display?.serviceChargeLegacyClientFallbackEnabled ?? true,
    serviceChargeLegacyDisableAllowedFrom:
      config.display?.serviceChargeLegacyDisableAllowedFrom ?? '2026-05-15',
  };
}

async function applyConfigurationChange(parameterName, newValue, userId) {
  const Configuration = Parse.Object.extend('Configuration');
  const query = new Parse.Query(Configuration);
  query.equalTo('isActive', true);
  query.descending('updatedAt');

  let config = await query.first({ useMasterKey: true });
  if (!config) {
    config = new Configuration();
    config.set('isActive', true);
  }

  const limitCamel = TRANSACTION_LIMIT_SNAKE_TO_CAMEL[parameterName];
  let appliedValue = newValue;
  if (limitCamel) {
    const nextLimits = { ...(config.get('limits') || {}), [limitCamel]: newValue };
    config.set('limits', nextLimits);
    appliedValue = newValue;
  } else if (TAX_CONFIG_KEYS.has(parameterName)) {
    const normalizedValue = parameterName === 'taxCollectionMode'
      ? normalizeTaxCollectionMode(newValue)
      : newValue;
    const nextTax = {
      ...(config.get('tax') || {}),
      [parameterName]: normalizedValue,
    };
    config.set('tax', nextTax);
    appliedValue = normalizedValue;
  } else {
    const valueToStore = parameterName === 'legalAppName' && typeof newValue === 'string'
      ? newValue.trim()
      : newValue;
    config.set(parameterName, valueToStore);
    appliedValue = valueToStore;
  }

  config.set('updatedBy', userId);
  config.set('updatedAt', new Date());

  await config.save(null, { useMasterKey: true });
  invalidateCache();

  console.log(`✅ Configuration '${parameterName}' updated to ${appliedValue} by ${userId}`);
}

module.exports = {
  formatValue,
  getOldValueFromConfig,
  buildDisplay,
  applyConfigurationChange,
};
