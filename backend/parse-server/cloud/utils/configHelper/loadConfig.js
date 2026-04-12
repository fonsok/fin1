'use strict';

const { DEFAULT_CONFIG } = require('./defaultConfig');
const { getCachedConfig, setCachedConfig, peekCacheOrNull } = require('./cache');

/**
 * @param {unknown} raw
 * @param {number} fallback
 * @returns {number}
 */
function resolvedPositiveLimit(raw, fallback) {
  if (raw === null || raw === undefined) return fallback;
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return n;
}

/**
 * Load configuration from database with caching.
 *
 * @param {boolean} forceRefresh
 * @returns {Promise<object>}
 */
async function loadConfig(forceRefresh = false) {
  const now = Date.now();

  const cached = getCachedConfig(now, forceRefresh);
  if (cached) {
    return cached;
  }

  try {
    const Configuration = Parse.Object.extend('Configuration');
    const query = new Parse.Query(Configuration);
    query.equalTo('isActive', true);
    query.descending('updatedAt');

    const config = await query.first({ useMasterKey: true });

    if (config) {
      const rawInitial = config.get('initialAccountBalance');
      const initialAccountBalance = Number(
        rawInitial !== undefined && rawInitial !== null ? rawInitial : DEFAULT_CONFIG.financial.initialAccountBalance,
      );

      const configData = {
        financial: {
          ...DEFAULT_CONFIG.financial,
          traderCommissionRate: Number(
            config.get('traderCommissionRate') ?? DEFAULT_CONFIG.financial.traderCommissionRate,
          ),
          appServiceChargeRate: Number(
            config.get('appServiceChargeRate')
            ?? config.get('platformServiceChargeRate')
            ?? DEFAULT_CONFIG.financial.appServiceChargeRate,
          ),
          minimumCashReserve: Number(
            config.get('minimumCashReserve') ?? DEFAULT_CONFIG.financial.minimumCashReserve,
          ),
          initialAccountBalance: Number.isFinite(initialAccountBalance)
            ? initialAccountBalance
            : DEFAULT_CONFIG.financial.initialAccountBalance,
          orderFeeRate: config.get('orderFeeRate') ?? DEFAULT_CONFIG.financial.orderFeeRate,
          orderFeeMin: config.get('orderFeeMin') ?? DEFAULT_CONFIG.financial.orderFeeMin,
          orderFeeMax: config.get('orderFeeMax') ?? DEFAULT_CONFIG.financial.orderFeeMax,
        },
        limits: {
          ...DEFAULT_CONFIG.limits,
          ...(config.get('limits') || {}),
          // Do not treat 0 as valid: Mongo/legacy rows may store 0; `??` would keep it and break FAQ placeholders & validation.
          minInvestment: resolvedPositiveLimit(
            config.get('minInvestment') ?? (config.get('limits') || {}).minInvestment,
            DEFAULT_CONFIG.limits.minInvestment,
          ),
          maxInvestment: resolvedPositiveLimit(
            config.get('maxInvestment') ?? (config.get('limits') || {}).maxInvestment,
            DEFAULT_CONFIG.limits.maxInvestment,
          ),
          dailyTransactionLimit:
            (config.get('limits') || {}).dailyTransactionLimit
            ?? (config.get('limits') || {}).daily_transaction_limit
            ?? config.get('dailyTransactionLimit')
            ?? config.get('daily_transaction_limit')
            ?? DEFAULT_CONFIG.limits.dailyTransactionLimit,
          weeklyTransactionLimit:
            (config.get('limits') || {}).weeklyTransactionLimit
            ?? (config.get('limits') || {}).weekly_transaction_limit
            ?? config.get('weeklyTransactionLimit')
            ?? config.get('weekly_transaction_limit')
            ?? DEFAULT_CONFIG.limits.weeklyTransactionLimit,
          monthlyTransactionLimit:
            (config.get('limits') || {}).monthlyTransactionLimit
            ?? (config.get('limits') || {}).monthly_transaction_limit
            ?? config.get('monthlyTransactionLimit')
            ?? config.get('monthly_transaction_limit')
            ?? DEFAULT_CONFIG.limits.monthlyTransactionLimit,
        },
        display: {
          ...DEFAULT_CONFIG.display,
          showCommissionBreakdownInCreditNote: config.get('showCommissionBreakdownInCreditNote') ?? DEFAULT_CONFIG.display.showCommissionBreakdownInCreditNote,
          maximumRiskExposurePercent: config.get('maximumRiskExposurePercent') ?? DEFAULT_CONFIG.display.maximumRiskExposurePercent,
          walletFeatureEnabled: config.get('walletFeatureEnabled') ?? DEFAULT_CONFIG.display.walletFeatureEnabled,
        },
        legal: {
          ...DEFAULT_CONFIG.legal,
          appName: config.get('legalAppName') ?? DEFAULT_CONFIG.legal.appName,
          platformName: config.get('legalPlatformName') ?? DEFAULT_CONFIG.legal.platformName,
        },
        _id: config.id,
        _updatedAt: config.get('updatedAt'),
        _updatedBy: config.get('updatedBy'),
      };

      setCachedConfig(configData, now);
      return configData;
    }

    setCachedConfig(DEFAULT_CONFIG, now);
    return DEFAULT_CONFIG;
  } catch (error) {
    console.error('Failed to load configuration:', error);
    return peekCacheOrNull() || DEFAULT_CONFIG;
  }
}

module.exports = { loadConfig };
