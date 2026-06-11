'use strict';

const { createCreditNoteDocument } = require('./creditNote');
const {
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
  createCollectionBillDocument,
} = require('./collectionBill');
const { createInvestmentReservationEigenbelegDocument } = require('./reservationEigenbeleg');
const { createPartialSellInternalBeleg } = require('./partialSellEigenbeleg');
const { createAppCommissionEigenbeleg } = require('./appCommissionEigenbeleg');
const { createWalletReceiptDocument } = require('./walletReceipt');
const {
  createTradeExecutionDocument,
  findExistingTradeExecutionDocument,
} = require('./tradeExecution');
const { ensureServiceChargeInvoiceDocument } = require('./serviceChargeInvoice');
const { resolveDocumentRefForFeeRefund } = require('./feeRefundRefs');

/** Tier 1 — document create/ensure use-cases (settlement, triggers). */
const tier1DocumentWrites = {
  createCreditNoteDocument,
  createCollectionBillDocument,
  createInvestmentReservationEigenbelegDocument,
  createPartialSellInternalBeleg,
  createAppCommissionEigenbeleg,
  createWalletReceiptDocument,
  createTradeExecutionDocument,
  findExistingTradeExecutionDocument,
  ensureServiceChargeInvoiceDocument,
};

/** Tier 2 — invariants / admin fee-refund resolution. */
const tier2InvariantsAndAdmin = {
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
  resolveDocumentRefForFeeRefund,
};

const publicSurface = {
  ...tier1DocumentWrites,
  ...tier2InvariantsAndAdmin,
};

const API_TIERS = {
  documentWrites: Object.keys(tier1DocumentWrites),
  invariantsAndAdmin: Object.keys(tier2InvariantsAndAdmin),
};

module.exports = { publicSurface, API_TIERS };
