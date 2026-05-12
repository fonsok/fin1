'use strict';

/**
 * Default configuration values.
 * Used when no configuration exists in the database.
 *
 * Product model (which role pays what):
 * - Investors: appServiceChargeRate (platform / app service charge on investments).
 *   They are not charged orderFee*, exchangeFee*, foreignCosts in the same way as traders.
 * - Traders: orderFee*, exchangeFee*, foreignCosts, trader commission on profit.
 *   They are not charged appServiceChargeRate.
 */
const DEFAULT_CONFIG = {
  financial: {
    orderFeeRate: 0.005,
    orderFeeMin: 5.0,
    orderFeeMax: 50.0,
    exchangeFeeRate: 0.0001,
    exchangeFeeMin: 0.50,
    exchangeFeeMax: 25.0,
    foreignCosts: 2.50,
    traderCommissionRate: 0.10,
    appServiceChargeRate: 0.02,
    appServiceChargeRateCompanies: 0.02,
    minimumCashReserve: 20.0,
    /** Cold-start default 0 €; persisted Configuration is admin/seed-owned — see startup reconcile skip in main.js. */
    initialAccountBalance: 0.0,
  },
  limits: {
    minDeposit: 10.0,
    maxDeposit: 100000.0,
    minInvestment: 20.0,
    maxInvestment: 100000.0,
    dailyTransactionLimit: 10000.0,
    weeklyTransactionLimit: 50000.0,
    monthlyTransactionLimit: 200000.0,
  },
  display: {
    showCommissionBreakdownInCreditNote: true,
    showDocumentReferenceLinksInAccountStatement: true,
    maximumRiskExposurePercent: 2.0,
    walletActionModeGlobal: 'disabled',
    walletActionModeInvestor: 'deposit_and_withdrawal',
    walletActionModeTrader: 'deposit_and_withdrawal',
    walletActionModeIndividual: 'deposit_and_withdrawal',
    walletActionModeCompany: 'deposit_and_withdrawal',
    // Legacy single-scope key kept for backward compatibility.
    walletActionMode: 'disabled',
    walletFeatureEnabled: false,
    // ADR-007 Phase 2 rollout flag: default false — flip via admin portal when ready.
    serviceChargeInvoiceFromBackend: false,
    // Stability rollout: keep legacy client fallback enabled by default.
    serviceChargeLegacyClientFallbackEnabled: true,
    // Earliest date when disabling the legacy fallback is allowed.
    serviceChargeLegacyDisableAllowedFrom: '2026-05-15',
  },
  legal: {
    appName: 'FIN1',
    platformName: 'App',
  },
  tax: {
    withholdingTaxRate: 0.25,
    solidaritySurchargeRate: 0.055,
    vatRate: 0.19,
    // Single governance switch for withholding tax bundle
    // (withholding tax + solidarity surcharge + church tax handling flow).
    taxCollectionMode: 'customer_self_reports',
  },
};

module.exports = { DEFAULT_CONFIG };
