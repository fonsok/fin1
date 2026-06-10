'use strict';

const BACKEND_DOC_TYPES = [
  'investorCollectionBill',
  'traderCollectionBill',
  'traderCreditNote',
  'invoice',
  'tradeExecution',
  'walletReceipt',
];

const BACKEND_STATEMENT_TYPES = [
  'trade_buy',
  'trade_sell',
  'trading_fees',
  'commission_credit',
  'commission_debit',
  'investment_return',
  'investment_activate',
  'residual_return',
  'withholding_tax_debit',
  'solidarity_surcharge_debit',
  'church_tax_debit',
];

module.exports = {
  BACKEND_DOC_TYPES,
  BACKEND_STATEMENT_TYPES,
};
