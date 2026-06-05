'use strict';

/**
 * GL mapping per `AccountStatement.entryType` for settlement postings.
 *
 * Each rule defines which AppLedgerEntry pair must accompany an AccountStatement row.
 * `null` means "no GL pair" (e.g. investment_activate / investment_return — those are
 * already covered by investmentEscrow.js CLT-LIAB-* shifts; posting another pair would
 * double-book the customer liability).
 */

const SETTLEMENT_GL_RULES = {
  commission_debit: {
    leg: 'commission',
    transactionType: 'commission',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'PLT-LIAB-COM',
  },
  commission_credit: {
    leg: 'commission',
    transactionType: 'commission',
    debitAccount: 'PLT-LIAB-COM',
    creditAccount: 'CLT-LIAB-AVA',
  },

  withholding_tax_debit: {
    leg: 'withholding_tax',
    transactionType: 'withholdingTax',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'PLT-TAX-WHT',
  },
  solidarity_surcharge_debit: {
    leg: 'solidarity_surcharge',
    transactionType: 'solidaritySurcharge',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'PLT-TAX-SOL',
  },
  church_tax_debit: {
    leg: 'church_tax',
    transactionType: 'churchTax',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'PLT-TAX-CHU',
  },

  trading_fees: {
    leg: 'trading_fees',
    transactionType: 'orderFee',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'PLT-REV-ORD',
  },

  residual_return: null,

  investment_activate: null,
  investment_return: null,
  investment_refund: null,

  trade_buy: {
    leg: 'trade_buy:cash',
    transactionType: 'tradeCash',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'BANK-TRT-CLT',
  },
  trade_sell: {
    leg: 'trade_sell:cash',
    transactionType: 'tradeCash',
    debitAccount: 'BANK-TRT-CLT',
    creditAccount: 'CLT-LIAB-AVA',
  },

  deposit: {
    leg: 'wallet:deposit',
    transactionType: 'walletDeposit',
    debitAccount: 'BANK-TRT-CLT',
    creditAccount: 'CLT-LIAB-AVA',
  },
  withdrawal: {
    leg: 'wallet:withdrawal',
    transactionType: 'walletWithdrawal',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'BANK-TRT-CLT',
  },
};

/**
 * Resolve which GL pair (if any) must accompany an AccountStatement row.
 * Returns null when no pair is defined.
 */
function getSettlementGLRule(entryType) {
  return Object.prototype.hasOwnProperty.call(SETTLEMENT_GL_RULES, entryType)
    ? SETTLEMENT_GL_RULES[entryType]
    : null;
}

function roleFromEntryType(entryType) {
  if (entryType === 'commission_credit' || entryType === 'trading_fees' ||
      entryType === 'trade_buy' || entryType === 'trade_sell') {
    return 'trader';
  }
  if (entryType === 'deposit' || entryType === 'withdrawal') {
    return 'user';
  }
  return 'investor';
}

module.exports = {
  SETTLEMENT_GL_RULES,
  getSettlementGLRule,
  roleFromEntryType,
};
