'use strict';

/**
 * Parameters that require 4-eyes approval for changes.
 */
const CRITICAL_PARAMETERS = [
  'investorCommissionRateTotal',
  'traderCommissionRate',
  'appCommissionRate',
  'appServiceChargeRate',
  'appServiceChargeRateCompanies',
  'serviceChargeLegacyClientFallbackEnabled',
  'serviceChargeLegacyDisableAllowedFrom',
  'withholdingTaxRate',
  'solidaritySurchargeRate',
  'vatRate',
  'taxCollectionMode',
  'legalAppName',
  'initialAccountBalance',
  'minimumCashReserve',
  'minInvestment',
  'maxInvestment',
  'maxTraderPartialSells',
  'maxTraderOpenDepotPositions',
  'poolBalanceDistributionThreshold',
  'maxPoolMirrorBuyOrderAmount',
  'minTraderBuyOrderAmount',
  'orderFeeRate',
  'orderFeeMin',
  'orderFeeMax',
  'daily_transaction_limit',
  'weekly_transaction_limit',
  'monthly_transaction_limit',
  'showDocumentReferenceLinksInAccountStatement',
  'showCommissionBreakdownInCreditNote',
  'showTraderDashboardInvestmentActiveStatus',
  'walletActionMode',
  'walletActionModeGlobal',
  'walletActionModeInvestor',
  'walletActionModeTrader',
  'walletActionModeIndividual',
  'walletActionModeCompany',
];

function isCriticalParameter(paramName) {
  return CRITICAL_PARAMETERS.includes(paramName);
}

module.exports = { CRITICAL_PARAMETERS, isCriticalParameter };
