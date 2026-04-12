// ============================================================================
// Parse Cloud Code
// utils/accountingHelper.js - Accounting & Document Helpers
// ============================================================================
//
// Centralised helpers for creating AccountStatement entries and
// accounting documents (Credit Notes, Collection Bills).
// Called from trade.js afterSave when a trade is completed.
//
// ============================================================================

'use strict';

const { bookAccountStatementEntry } = require('./accountingHelper/statements');
const {
  createCreditNoteDocument,
  createCollectionBillDocument,
  createWalletReceiptDocument,
  createTradeExecutionDocument,
} = require('./accountingHelper/documents');
const { settleAndDistribute, settleCompletedTrade } = require('./accountingHelper/settlement');

module.exports = {
  bookAccountStatementEntry,
  createCreditNoteDocument,
  createCollectionBillDocument,
  createWalletReceiptDocument,
  createTradeExecutionDocument,
  settleAndDistribute,
  settleCompletedTrade,
};
