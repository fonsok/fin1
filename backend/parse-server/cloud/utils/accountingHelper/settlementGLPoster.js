'use strict';

/**
 * Posts AccountStatement + matching AppLedgerEntry pair (ADR-010 / PR4).
 *
 * Fail-open: if the GL pair fails, the AccountStatement row stays authoritative;
 * discrepancy is logged (console.error) and surfaces in App Ledger health checks.
 */

const { postLedgerPair } = require('./journal');
const { bookAccountStatementEntry, composeStatementBusinessReference } = require('./accountStatementWriter');
const { getSettlementGLRule, roleFromEntryType } = require('./settlementGLRules');
const { resolveTraderCustomerBookingContext } = require('../../services/poolMirrorActivation/traderCustomerBookingPolicy');

const ORDER_FEE_COMPONENTS = [
  { key: 'orderFee',     account: 'PLT-REV-ORD', leg: 'order_fee:orderFee',     transactionType: 'orderFee' },
  { key: 'exchangeFee',  account: 'PLT-REV-EXC', leg: 'order_fee:exchangeFee',  transactionType: 'exchangeFee' },
  { key: 'foreignCosts', account: 'PLT-REV-FRG', leg: 'order_fee:foreignCosts', transactionType: 'foreignCosts' },
];

/**
 * Posts the AccountStatement row AND the matching GL pair (if any) for a
 * settlement entry. Idempotent on both sides:
 *   - AccountStatement: callers gate by (tradeId + entryType + source) — no
 *     change here.
 *   - AppLedgerEntry: gated by (referenceId, transactionType, metadata.leg)
 *     inside `postLedgerPair`.
 *
 * `feeBreakdown` (optional, only used for `trading_fees`):
 *   { orderFee?: number, exchangeFee?: number, foreignCosts?: number }
 */
async function bookSettlementEntry({
  userId,
  userRole,
  entryType,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  investmentNumber,
  description,
  referenceDocumentId,
  referenceDocumentNumber,
  feeBreakdown,
  ledgerReference,
  businessCaseId,
  enforceReferenceDocumentId = true,
}) {
  const bookingContext = await resolveTraderCustomerBookingContext({
    tradeId,
    tradeNumber,
    entryType,
    userRole,
  });
  const resolvedTradeId = bookingContext.tradeId;
  const resolvedTradeNumber = bookingContext.tradeNumber;

  const stmt = await bookAccountStatementEntry({
    userId,
    entryType,
    amount,
    tradeId: resolvedTradeId,
    tradeNumber: resolvedTradeNumber,
    investmentId,
    investmentNumber,
    description,
    referenceDocumentId,
    referenceDocumentNumber,
    businessCaseId,
    enforceReferenceDocumentId,
  });

  try {
    await postSettlementGLPair({
      userId,
      userRole,
      entryType,
      amount,
      tradeId: resolvedTradeId,
      tradeNumber: resolvedTradeNumber,
      investmentId,
      investmentNumber,
      description,
      referenceDocumentId,
      referenceDocumentNumber,
      feeBreakdown,
      ledgerReference,
      accountStatementId: stmt.id,
      businessCaseId,
    });
  } catch (err) {
    console.error(
      `❌ postSettlementGLPair failed for entryType=${entryType} tradeId=${tradeId} investmentId=${investmentId || ''}:`,
      err && err.message ? err.message : err,
    );
  }

  return stmt;
}

async function postSettlementGLPair({
  userId,
  userRole,
  entryType,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  investmentNumber,
  description,
  referenceDocumentId,
  referenceDocumentNumber,
  feeBreakdown,
  ledgerReference,
  accountStatementId,
  businessCaseId,
}) {
  const rule = getSettlementGLRule(entryType);
  if (!rule) return [];

  const referenceId = (ledgerReference && ledgerReference.referenceId) || tradeId || investmentId;
  const referenceType = (ledgerReference && ledgerReference.referenceType) || (tradeId ? 'Trade' : 'Investment');
  if (!referenceId) return [];

  const invNumTrim = String(investmentNumber || '').trim();
  const businessReference = composeStatementBusinessReference({
    tradeNumber,
    referenceDocumentNumber,
    investmentNumber: invNumTrim,
  });
  const bcTrim = String(businessCaseId || '').trim();
  const sharedMetadata = {
    accountStatementId: accountStatementId || '',
    accountStatementEntryType: entryType,
    tradeId: tradeId || '',
    tradeNumber: tradeNumber || '',
    businessReference: businessReference || '',
    investmentId: investmentId || '',
    investmentNumber: invNumTrim,
    referenceDocumentId: referenceDocumentId || '',
    referenceDocumentNumber: referenceDocumentNumber || '',
    ...(bcTrim ? { businessCaseId: bcTrim } : {}),
  };

  if (entryType === 'trading_fees' && feeBreakdown) {
    return postOrderFeeBreakdown({
      userId,
      userRole,
      tradeId,
      referenceId,
      referenceType,
      description,
      sharedMetadata,
      feeBreakdown,
    });
  }

  return postLedgerPair({
    debitAccount: rule.debitAccount,
    creditAccount: rule.creditAccount,
    amount,
    userId,
    userRole: userRole || roleFromEntryType(entryType),
    transactionType: rule.transactionType,
    referenceId,
    referenceType,
    description,
    metadata: sharedMetadata,
    leg: rule.leg,
  });
}

async function postOrderFeeBreakdown({
  userId,
  userRole,
  tradeId,
  referenceId,
  referenceType,
  description,
  sharedMetadata,
  feeBreakdown,
}) {
  const written = [];
  for (const component of ORDER_FEE_COMPONENTS) {
    const componentAmount = Number(feeBreakdown[component.key] || 0);
    if (!Number.isFinite(componentAmount) || componentAmount <= 0) continue;
    // eslint-disable-next-line no-await-in-loop
    const pair = await postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: component.account,
      amount: componentAmount,
      userId,
      userRole: userRole || 'trader',
      transactionType: component.transactionType,
      referenceId,
      referenceType,
      description: description || `Handelsgebühr (${component.key}) Trade ${tradeId || referenceId}`,
      metadata: Object.assign({ feeComponent: component.key }, sharedMetadata),
      leg: component.leg,
    });
    written.push(...pair);
  }
  return written;
}

module.exports = {
  bookSettlementEntry,
  getSettlementGLRule,
  ORDER_FEE_COMPONENTS,
};
