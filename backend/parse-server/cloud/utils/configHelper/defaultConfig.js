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
    minimumCashReserve: 20.0,
    /** Only the admin portal may raise this; cold start / no DB row = 0 €. */
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
    maximumRiskExposurePercent: 2.0,
    walletFeatureEnabled: false,
  },
  legal: {
    appName: 'FIN1',
    platformName: 'App',
  },
};

module.exports = { DEFAULT_CONFIG };
