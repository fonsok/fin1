'use strict';

const { loadConfig } = require('./loadConfig');

async function getTraderCommissionRate() {
  const config = await loadConfig();
  return config.financial.traderCommissionRate;
}

async function getAppCommissionRate() {
  const config = await loadConfig();
  return Number(config.financial.appCommissionRate) || 0;
}

/**
 * Trader + app success-provision rates. Investor Collection Bill uses `totalRate`
 * as a single "Commission" line; settlement splits credits to trader vs PLT-REV-COM.
 */
async function getCommissionRateBundle() {
  const config = await loadConfig();
  const traderRate = Number(config.financial.traderCommissionRate) || 0;
  const appRate = Number(config.financial.appCommissionRate) || 0;
  return {
    traderRate,
    appRate,
    totalRate: traderRate + appRate,
  };
}

async function getAppServiceChargeRate() {
  const config = await loadConfig();
  return config.financial.appServiceChargeRate;
}

async function getAppServiceChargeRateForAccountType(accountType = 'individual') {
  const config = await loadConfig();
  if (String(accountType).toLowerCase() === 'company') {
    return config.financial.appServiceChargeRateCompanies;
  }
  return config.financial.appServiceChargeRate;
}

async function getMinimumCashReserve() {
  const config = await loadConfig();
  return config.financial.minimumCashReserve;
}

async function getInitialAccountBalance() {
  const config = await loadConfig();
  return config.financial.initialAccountBalance;
}

async function getOrderFeeConfig() {
  const config = await loadConfig();
  return {
    rate: config.financial.orderFeeRate,
    min: config.financial.orderFeeMin,
    max: config.financial.orderFeeMax,
  };
}

async function getFinancialConfig() {
  const config = await loadConfig();
  return config.financial;
}

module.exports = {
  getTraderCommissionRate,
  getAppCommissionRate,
  getCommissionRateBundle,
  getAppServiceChargeRate,
  getAppServiceChargeRateForAccountType,
  getMinimumCashReserve,
  getInitialAccountBalance,
  getOrderFeeConfig,
  getFinancialConfig,
};
