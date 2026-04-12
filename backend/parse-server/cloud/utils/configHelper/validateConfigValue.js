'use strict';

/**
 * Validate a configuration value (admin / 4-eyes workflow).
 *
 * @param {string} paramName
 * @param {*} value
 * @returns {{ valid: boolean, error?: string }}
 */
function validateConfigValue(paramName, value) {
  const validations = {
    traderCommissionRate: {
      type: 'number',
      min: 0.0,
      max: 1.0,
      errorMsg: 'Trader-Provisionssatz muss zwischen 0,0 (0 %) und 1,0 (100 %) liegen',
    },
    appServiceChargeRate: {
      type: 'number',
      min: 0.0,
      max: 0.1,
      errorMsg: 'App-Servicegebühr muss zwischen 0,0 (0 %) und 0,1 (10 %) liegen',
    },
    minimumCashReserve: {
      type: 'number',
      min: 0.01,
      max: 1000.0,
      errorMsg: 'Mindest-Cash-Reserve muss zwischen 0,01 € und 1.000,00 € liegen',
    },
    initialAccountBalance: {
      type: 'number',
      min: 0.0,
      max: 1000000.0,
      errorMsg: 'Initiales Kontoguthaben muss zwischen 0,00 € und 1.000.000,00 € liegen (nur Admin-Portal)',
    },
    orderFeeRate: {
      type: 'number',
      min: 0.0,
      max: 0.1,
      errorMsg: 'Order-Gebührensatz muss zwischen 0,0 (0 %) und 0,1 (10 %) liegen',
    },
    orderFeeMin: {
      type: 'number',
      min: 0.0,
      max: 100.0,
      errorMsg: 'Order-Gebühr Minimum muss zwischen 0,00 € und 100,00 € liegen',
    },
    orderFeeMax: {
      type: 'number',
      min: 1.0,
      max: 500.0,
      errorMsg: 'Order-Gebühr Maximum muss zwischen 1,00 € und 500,00 € liegen',
    },
    maximumRiskExposurePercent: {
      type: 'number',
      min: 0,
      max: 100,
      errorMsg: 'Maximale Risikoexposition muss zwischen 0 und 100 liegen',
    },
    walletFeatureEnabled: {
      type: 'boolean',
      errorMsg: 'Wallet-Feature muss true oder false sein',
    },
    minInvestment: {
      type: 'number',
      min: 0.01,
      max: 1000000.0,
      errorMsg: 'Mindestinvestment muss zwischen 0,01 € und 1.000.000,00 € liegen',
    },
    maxInvestment: {
      type: 'number',
      min: 0.01,
      max: 1000000.0,
      errorMsg: 'Maximuminvestmentbetrag muss zwischen 0,01 € und 1.000.000,00 € liegen',
    },
    daily_transaction_limit: {
      type: 'number',
      min: 100,
      max: 500000,
      errorMsg: 'Daily transaction limit must be between 100,00 € and 500.000,00 €',
    },
    weekly_transaction_limit: {
      type: 'number',
      min: 1000,
      max: 500000,
      errorMsg: 'Weekly transaction limit must be between 1.000,00 € and 500.000,00 €',
    },
    monthly_transaction_limit: {
      type: 'number',
      min: 5000,
      max: 2000000,
      errorMsg: 'Monthly transaction limit must be between 5.000,00 € and 2.000.000,00 €',
    },
  };

  const validation = validations[paramName];
  if (!validation) {
    return { valid: true };
  }

  if (validation.type === 'boolean') {
    const boolVal = value === true || value === false || value === 1 || value === 0;
    return boolVal ? { valid: true } : { valid: false, error: validation.errorMsg };
  }

  if (typeof value !== validation.type) {
    return { valid: false, error: `${paramName} muss vom Typ ${validation.type} sein` };
  }

  if (validation.min !== undefined && (value < validation.min || value > validation.max)) {
    return { valid: false, error: validation.errorMsg };
  }

  return { valid: true };
}

/**
 * Ensure minInvestment ≤ maxInvestment after a proposed change (admin / 4-eyes).
 *
 * @param {string} parameterName
 * @param {number} newValue
 * @param {object} limits - Current merged limits from loadConfig()
 * @returns {{ valid: boolean, error?: string }}
 */
function validateInvestmentAmountOrdering(parameterName, newValue, limits) {
  if (parameterName !== 'minInvestment' && parameterName !== 'maxInvestment') {
    return { valid: true };
  }
  const { DEFAULT_CONFIG } = require('./defaultConfig');
  const min =
    parameterName === 'minInvestment'
      ? newValue
      : (limits.minInvestment ?? DEFAULT_CONFIG.limits.minInvestment);
  const max =
    parameterName === 'maxInvestment'
      ? newValue
      : (limits.maxInvestment ?? DEFAULT_CONFIG.limits.maxInvestment);
  if (min > max) {
    return {
      valid: false,
      error: 'Mindestinvestmentbetrag darf den Maximuminvestmentbetrag nicht übersteigen.',
    };
  }
  return { valid: true };
}

module.exports = { validateConfigValue, validateInvestmentAmountOrdering };
