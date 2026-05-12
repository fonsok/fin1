'use strict';

/**
 * Configuration helper (barrel).
 *
 * Call sites MUST use an explicit path ending in `configHelper/index.js`, e.g.:
 *   require('../../utils/configHelper/index.js')
 * so a stray legacy `utils/configHelper.js` on disk cannot shadow this package
 * (Node would otherwise prefer the `.js` file over the `configHelper/` directory).
 */

const { CACHE_TTL_MS, invalidateCache } = require('./cache');
const { DEFAULT_CONFIG } = require('./defaultConfig');
const { CRITICAL_PARAMETERS, isCriticalParameter } = require('./criticalParameters');
const { TRANSACTION_LIMIT_SNAKE_TO_CAMEL, validateTransactionLimitOrdering } = require('./transactionLimits');
const { loadConfig } = require('./loadConfig');
const {
  getTraderCommissionRate,
  getAppServiceChargeRate,
  getAppServiceChargeRateForAccountType,
  getMinimumCashReserve,
  getInitialAccountBalance,
  getOrderFeeConfig,
  getFinancialConfig,
} = require('./getters');
const { validateConfigValue, validateInvestmentAmountOrdering } = require('./validateConfigValue');

module.exports = {
  loadConfig,
  invalidateCache,
  getTraderCommissionRate,
  getAppServiceChargeRate,
  getAppServiceChargeRateForAccountType,
  getPlatformServiceChargeRate: getAppServiceChargeRate,
  getMinimumCashReserve,
  getInitialAccountBalance,
  getOrderFeeConfig,
  getFinancialConfig,
  validateConfigValue,
  validateInvestmentAmountOrdering,
  isCriticalParameter,
  validateTransactionLimitOrdering,
  TRANSACTION_LIMIT_SNAKE_TO_CAMEL,
  DEFAULT_CONFIG,
  CRITICAL_PARAMETERS,
  CACHE_TTL_MS,
};
