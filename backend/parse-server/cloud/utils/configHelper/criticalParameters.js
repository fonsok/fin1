'use strict';

/**
 * Parameters that require 4-eyes approval for changes.
 */
const CRITICAL_PARAMETERS = [
  'traderCommissionRate',
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
  'orderFeeRate',
  'orderFeeMin',
  'orderFeeMax',
  'daily_transaction_limit',
  'weekly_transaction_limit',
  'monthly_transaction_limit',
  'showDocumentReferenceLinksInAccountStatement',
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
