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
  getAppCommissionRate,
  getCommissionRateBundle,
  getAppServiceChargeRate,
  getAppServiceChargeRateForAccountType,
  getMinimumCashReserve,
  getInitialAccountBalance,
  getOrderFeeConfig,
  getFinancialConfig,
} = require('./getters');
const { validateConfigValue, validateInvestmentAmountOrdering, validateInvestorCommissionRateTotalMatch } = require('./validateConfigValue');
const { bundleToSettlementRates } = require('./commissionRateBundle');
const {
  USER_COMMISSION_OVERRIDE_FIELDS,
  COMMISSION_OVERRIDE_ROLES,
  normalizeCommissionOverrideRole,
  readUserCommissionRateOverride,
  resolveCommissionRateBundle,
  createCommissionRateResolver,
  effectiveCommissionRateFromAmount,
} = require('./resolveCommissionRateBundle');
const {
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  normalizeAppServiceChargeRate,
  readUserAppServiceChargeOverride,
  resolveAppServiceChargeRate,
  createAppServiceChargeResolver,
} = require('./resolveAppServiceChargeRate');

const {
  getMaxTraderPartialSells,
  countTraderPartialSellEvents,
  assertTraderPartialSellWithinLimit,
} = require('./traderPartialSellLimits');

const {
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
  getMaxTraderOpenDepotPositions,
  normalizeMaxOpenDepotPositions,
  readUserMaxOpenDepotPositionsOverride,
  resolveMaxOpenDepotPositions,
} = require('./resolveMaxOpenDepotPositions');

const {
  countOpenTraderDepotPositions,
  assertTraderCanOpenNewDepotPosition,
} = require('./traderOpenDepotLimits');

const {
  normalizeMinTraderBuyOrderAmount,
  getMinTraderBuyOrderAmount,
  assertTraderBuyOrderMeetsMinimum,
} = require('./minTraderBuyOrderAmount');

module.exports = {
  loadConfig,
  invalidateCache,
  getTraderCommissionRate,
  getAppCommissionRate,
  getCommissionRateBundle,
  getAppServiceChargeRate,
  getAppServiceChargeRateForAccountType,
  getPlatformServiceChargeRate: getAppServiceChargeRate,
  getMinimumCashReserve,
  getInitialAccountBalance,
  getOrderFeeConfig,
  getFinancialConfig,
  validateConfigValue,
  validateInvestmentAmountOrdering,
  validateInvestorCommissionRateTotalMatch,
  isCriticalParameter,
  validateTransactionLimitOrdering,
  TRANSACTION_LIMIT_SNAKE_TO_CAMEL,
  DEFAULT_CONFIG,
  CRITICAL_PARAMETERS,
  CACHE_TTL_MS,
  getMaxTraderPartialSells,
  countTraderPartialSellEvents,
  assertTraderPartialSellWithinLimit,
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
  getMaxTraderOpenDepotPositions,
  normalizeMaxOpenDepotPositions,
  readUserMaxOpenDepotPositionsOverride,
  resolveMaxOpenDepotPositions,
  countOpenTraderDepotPositions,
  assertTraderCanOpenNewDepotPosition,
  normalizeMinTraderBuyOrderAmount,
  getMinTraderBuyOrderAmount,
  assertTraderBuyOrderMeetsMinimum,
  USER_COMMISSION_OVERRIDE_FIELDS,
  COMMISSION_OVERRIDE_ROLES,
  normalizeCommissionOverrideRole,
  readUserCommissionRateOverride,
  resolveCommissionRateBundle,
  createCommissionRateResolver,
  effectiveCommissionRateFromAmount,
  bundleToSettlementRates,
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  normalizeAppServiceChargeRate,
  readUserAppServiceChargeOverride,
  resolveAppServiceChargeRate,
  createAppServiceChargeResolver,
};
