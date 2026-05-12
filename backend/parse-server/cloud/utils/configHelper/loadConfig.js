'use strict';

const { DEFAULT_CONFIG } = require('./defaultConfig');
const { getCachedConfig, setCachedConfig, peekCacheOrNull } = require('./cache');
const { normalizeTaxCollectionMode } = require('./taxCollectionMode');

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

function normalizeWalletActionMode(rawValue, fallbackBool) {
  const allowedModes = new Set([
    'disabled',
    'deposit_only',
    'withdrawal_only',
    'deposit_and_withdrawal',
  ]);
  if (typeof rawValue === 'string' && allowedModes.has(rawValue)) {
    return rawValue;
  }
  return fallbackBool === true ? 'deposit_and_withdrawal' : 'disabled';
}

function normalizeScopedWalletModes(rawDisplay, fallbackBool) {
  const legacy = normalizeWalletActionMode(rawDisplay?.walletActionMode, fallbackBool);
  return {
    walletActionModeGlobal: normalizeWalletActionMode(rawDisplay?.walletActionModeGlobal, fallbackBool),
    walletActionModeInvestor: normalizeWalletActionMode(rawDisplay?.walletActionModeInvestor, true),
    walletActionModeTrader: normalizeWalletActionMode(rawDisplay?.walletActionModeTrader, true),
    walletActionModeIndividual: normalizeWalletActionMode(rawDisplay?.walletActionModeIndividual, true),
    walletActionModeCompany: normalizeWalletActionMode(rawDisplay?.walletActionModeCompany, true),
    walletActionMode: legacy,
  };
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

      const walletModes = normalizeScopedWalletModes({
        walletActionMode: config.get('walletActionMode'),
        walletActionModeGlobal: config.get('walletActionModeGlobal'),
        walletActionModeInvestor: config.get('walletActionModeInvestor'),
        walletActionModeTrader: config.get('walletActionModeTrader'),
        walletActionModeIndividual: config.get('walletActionModeIndividual'),
        walletActionModeCompany: config.get('walletActionModeCompany'),
      }, config.get('walletFeatureEnabled') ?? DEFAULT_CONFIG.display.walletFeatureEnabled);

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
          appServiceChargeRateCompanies: Number(
            config.get('appServiceChargeRateCompanies')
            ?? config.get('platformServiceChargeRateCompanies')
            ?? DEFAULT_CONFIG.financial.appServiceChargeRateCompanies,
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
          showDocumentReferenceLinksInAccountStatement:
            config.get('showDocumentReferenceLinksInAccountStatement')
            ?? DEFAULT_CONFIG.display.showDocumentReferenceLinksInAccountStatement,
          maximumRiskExposurePercent: config.get('maximumRiskExposurePercent') ?? DEFAULT_CONFIG.display.maximumRiskExposurePercent,
          ...walletModes,
          walletFeatureEnabled: config.get('walletFeatureEnabled') ?? DEFAULT_CONFIG.display.walletFeatureEnabled,
          // ADR-007 Phase 2 rollout flag: optional, default false.
          serviceChargeInvoiceFromBackend: config.get('serviceChargeInvoiceFromBackend') ?? DEFAULT_CONFIG.display.serviceChargeInvoiceFromBackend,
          serviceChargeLegacyClientFallbackEnabled:
            config.get('serviceChargeLegacyClientFallbackEnabled')
            ?? DEFAULT_CONFIG.display.serviceChargeLegacyClientFallbackEnabled,
          serviceChargeLegacyDisableAllowedFrom:
            config.get('serviceChargeLegacyDisableAllowedFrom')
            ?? DEFAULT_CONFIG.display.serviceChargeLegacyDisableAllowedFrom,
        },
        legal: {
          ...DEFAULT_CONFIG.legal,
          appName: config.get('legalAppName') ?? DEFAULT_CONFIG.legal.appName,
          platformName: config.get('legalPlatformName') ?? DEFAULT_CONFIG.legal.platformName,
        },
        tax: {
          ...DEFAULT_CONFIG.tax,
          ...(config.get('tax') || {}),
          withholdingTaxRate: Number(
            (config.get('tax') || {}).withholdingTaxRate
            ?? config.get('withholdingTaxRate')
            ?? DEFAULT_CONFIG.tax.withholdingTaxRate
          ),
          solidaritySurchargeRate: Number(
            (config.get('tax') || {}).solidaritySurchargeRate
            ?? config.get('solidaritySurchargeRate')
            ?? DEFAULT_CONFIG.tax.solidaritySurchargeRate
          ),
          vatRate: Number(
            (config.get('tax') || {}).vatRate
            ?? config.get('vatRate')
            ?? DEFAULT_CONFIG.tax.vatRate
          ),
          taxCollectionMode:
            normalizeTaxCollectionMode(
              (config.get('tax') || {}).taxCollectionMode
              ?? config.get('taxCollectionMode')
              ?? DEFAULT_CONFIG.tax.taxCollectionMode,
            ),
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
