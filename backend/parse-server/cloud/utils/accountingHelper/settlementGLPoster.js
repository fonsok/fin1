'use strict';

/**
 * Posts AccountStatement + matching AppLedgerEntry pair (ADR-010 / PR4).
 *
 * Fail-open: if the GL pair fails, the AccountStatement row stays authoritative;
 * discrepancy is logged (console.error) and surfaces in App Ledger health checks.
 */

const { postLedgerPair, hasLeg } = require('./journal');
const { bookAccountStatementEntry, composeStatementBusinessReference } = require('./accountStatementWriter');
const { getSettlementGLRule, roleFromEntryType } = require('./settlementGLRules');
const { resolveTraderCustomerBookingContext } = require('../../services/poolMirrorActivation/traderCustomerBookingPolicy');

/** Per-investor settlement rows need distinct GL legs on the same trade reference. */
function resolveSettlementGLLeg(baseLeg, investmentId) {
  const inv = String(investmentId || '').trim();
  if (!inv) return baseLeg;
  return `${baseLeg}:inv:${inv}`;
}

/** Remove pre-fix duplicate pair (`leg: commission`) after per-investor leg backfill. */
async function removeSupersededLegacyCommissionLeg({
  referenceId,
  referenceType,
  transactionType,
  userId,
  investmentId,
}) {
  const inv = String(investmentId || '').trim();
  if (!inv || !referenceId || !userId) return 0;

  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', referenceId);
  if (referenceType) q.equalTo('referenceType', referenceType);
  if (transactionType) q.equalTo('transactionType', transactionType);
  q.equalTo('userId', userId);
  q.limit(20);
  const rows = await q.find({ useMasterKey: true });
  const legacy = rows.filter((row) => (row.get('metadata') || {}).leg === 'commission');
  if (!legacy.length) return 0;
  await Parse.Object.destroyAll(legacy, { useMasterKey: true });
  return legacy.length;
}

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
  customerDisplaySnapshot,
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
    customerDisplaySnapshot,
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
    leg: resolveSettlementGLLeg(rule.leg, investmentId),
  });
}

/**
 * Replay missing AppLedger pairs from existing AccountStatement rows (repair path).
 */
async function backfillMissingSettlementGLForTrade(tradeId, { dryRun = false } = {}) {
  const tid = String(tradeId || '').trim();
  if (!tid) {
    throw new Error('backfillMissingSettlementGLForTrade: tradeId required');
  }

  const stmtQuery = new Parse.Query('AccountStatement');
  stmtQuery.equalTo('tradeId', tid);
  stmtQuery.equalTo('source', 'backend');
  stmtQuery.limit(500);
  const statements = await stmtQuery.find({ useMasterKey: true });

  const results = [];
  for (const stmt of statements) {
    const entryType = String(stmt.get('entryType') || '');
    const rule = getSettlementGLRule(entryType);
    if (!rule) {
      results.push({ statementId: stmt.id, entryType, status: 'no_gl_rule' });
      continue;
    }

    const investmentId = stmt.get('investmentId') || '';
    const leg = resolveSettlementGLLeg(rule.leg, investmentId);
    const referenceId = tid;
    const referenceType = 'Trade';
    const alreadyPosted = await hasLeg({
      referenceId,
      referenceType,
      transactionType: rule.transactionType,
      leg,
    });
    if (alreadyPosted) {
      results.push({ statementId: stmt.id, entryType, status: 'exists', leg });
      continue;
    }

    if (dryRun) {
      results.push({ statementId: stmt.id, entryType, status: 'would_post', leg });
      continue;
    }

    if (entryType === 'commission_debit' && investmentId) {
      const removedLegacy = await removeSupersededLegacyCommissionLeg({
        referenceId: tid,
        referenceType: 'Trade',
        transactionType: rule.transactionType,
        userId: stmt.get('userId'),
        investmentId,
      });
      if (removedLegacy > 0) {
        results.push({
          statementId: stmt.id,
          entryType,
          status: 'removed_legacy_commission_leg',
          removedRows: removedLegacy,
        });
      }
    }

    const pairs = await postSettlementGLPair({
      userId: stmt.get('userId'),
      userRole: roleFromEntryType(entryType),
      entryType,
      amount: stmt.get('amount'),
      tradeId: tid,
      tradeNumber: stmt.get('tradeNumber'),
      investmentId,
      investmentNumber: stmt.get('investmentNumber'),
      description: stmt.get('description'),
      referenceDocumentId: stmt.get('referenceDocumentId'),
      referenceDocumentNumber: stmt.get('referenceDocumentNumber'),
      accountStatementId: stmt.id,
      businessCaseId: stmt.get('businessCaseId'),
    });
    results.push({
      statementId: stmt.id,
      entryType,
      status: pairs.length > 0 ? 'posted' : 'skipped',
      leg,
      ledgerRows: pairs.length,
    });
  }

  const posted = results.filter((r) => r.status === 'posted').length;
  const wouldPost = results.filter((r) => r.status === 'would_post').length;
  return {
    tradeId: tid,
    dryRun,
    checkedStatements: statements.length,
    posted,
    wouldPost,
    results,
  };
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
  resolveSettlementGLLeg,
  removeSupersededLegacyCommissionLeg,
  backfillMissingSettlementGLForTrade,
  ORDER_FEE_COMPONENTS,
};
