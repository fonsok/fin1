'use strict';

const {
  CLT_LIAB_PTR,
  CLT_LIAB_TRD_LEGACY,
} = require('../clientLiabilityAccounts');

const POOL_TRADE_ACCOUNTS = [CLT_LIAB_PTR, CLT_LIAB_TRD_LEGACY];

/** Investor-Erfolg bei Trade-Abwicklung (Schritt 4, Gegenkonto zu AVA). */
const CLT_EQT_INV_PNL = 'CLT-EQT-INV-PNL';

const TRANSACTION_TYPE = 'investmentEscrow';
const REFERENCE_TYPE = 'Investment';

const TRADE_SETTLEMENT_ESCROW_LEGS = [
  'tradeSettlementPoolRelease',
  'tradeSettlementPartialPoolRelease',
  'tradeSettlementProfitRelease',
  'tradeSettlementTransferGap',
];

module.exports = {
  POOL_TRADE_ACCOUNTS,
  CLT_EQT_INV_PNL,
  TRANSACTION_TYPE,
  REFERENCE_TYPE,
  TRADE_SETTLEMENT_ESCROW_LEGS,
};
