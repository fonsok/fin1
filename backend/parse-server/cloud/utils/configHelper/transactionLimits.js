'use strict';

const { DEFAULT_CONFIG } = require('./defaultConfig');

const TRANSACTION_LIMIT_SNAKE_TO_CAMEL = {
  daily_transaction_limit: 'dailyTransactionLimit',
  weekly_transaction_limit: 'weeklyTransactionLimit',
  monthly_transaction_limit: 'monthlyTransactionLimit',
};

/**
 * Ensure daily ≤ weekly ≤ monthly when changing any of the three caps.
 *
 * @param {string} parameterName
 * @param {number} newValue
 * @param {object} limits - Current merged limits object from loadConfig()
 * @returns {{ valid: boolean, error?: string }}
 */
function validateTransactionLimitOrdering(parameterName, newValue, limits) {
  const keys = Object.keys(TRANSACTION_LIMIT_SNAKE_TO_CAMEL);
  if (!keys.includes(parameterName)) {
    return { valid: true };
  }

  const daily = parameterName === 'daily_transaction_limit'
    ? newValue
    : (limits.dailyTransactionLimit ?? DEFAULT_CONFIG.limits.dailyTransactionLimit);
  const weekly = parameterName === 'weekly_transaction_limit'
    ? newValue
    : (limits.weeklyTransactionLimit ?? DEFAULT_CONFIG.limits.weeklyTransactionLimit);
  const monthly = parameterName === 'monthly_transaction_limit'
    ? newValue
    : (limits.monthlyTransactionLimit ?? DEFAULT_CONFIG.limits.monthlyTransactionLimit);

  if (daily <= weekly && weekly <= monthly) {
    return { valid: true };
  }
  return {
    valid: false,
    error: 'Transaction limits must satisfy daily ≤ weekly ≤ monthly',
  };
}

module.exports = { TRANSACTION_LIMIT_SNAKE_TO_CAMEL, validateTransactionLimitOrdering };
