'use strict';

const { round2 } = require('./shared');
const { postLedgerPair } = require('./journal');

// ============================================================================
// AccountStatement (Personenkonto / Sub-Ledger) writer.
//
// `bookAccountStatementEntry` keeps its existing single-row contract for any
// caller that still wants the legacy behaviour (no GL pair). New callers
// should use `bookSettlementEntry` which writes BOTH the AccountStatement row
// and the matching balanced AppLedgerEntry pair (see ADR-010 / PR4 in
// LEDGER_CHART_OF_ACCOUNTS_ROADMAP.md).
//
// Fail-open invariant: if the GL pair fails (e.g. transient connectivity or
// strict mapping rejecting an unknown account), the AccountStatement row stays
// authoritative for the customer balance — the discrepancy is logged and
// surfaces in the App Ledger health check (PR4 follow-up). This mirrors the
// existing Beleg/contra-posting strategy in triggers/invoice/.
// ============================================================================

function composeStatementBusinessReference({ tradeNumber, referenceDocumentNumber, investmentNumber }) {
  const normalizedTradeNumber = tradeNumber === undefined || tradeNumber === null
    ? ''
    : String(tradeNumber);
  const tradeRef = normalizedTradeNumber ? `TRD-${normalizedTradeNumber}` : '';
  const docNum = String(referenceDocumentNumber || '').trim();
  const docRef = docNum ? `Beleg ${docNum}` : '';
  const invNum = String(investmentNumber || '').trim();
  const invRef = invNum ? `Inv. ${invNum}` : '';
  const parts = [tradeRef, docRef, invRef].filter(Boolean);
  return parts.join(' · ');
}

async function bookAccountStatementEntry({
  userId,
  entryType,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  investmentNumber,
  description,
  referenceDocumentId,
  referenceDocumentNumber,
  businessCaseId,
  enforceReferenceDocumentId = true,
}) {
  if (enforceReferenceDocumentId && (!referenceDocumentId || !referenceDocumentNumber)) {
    throw new Error(
      `GoB violation blocked: AccountStatement booking requires referenceDocumentId + referenceDocumentNumber (entryType=${entryType}, userId=${userId}, tradeId=${tradeId || ''}, investmentId=${investmentId || ''})`,
    );
  }

  const AccountStatement = Parse.Object.extend('AccountStatement');

  const lastEntry = await new Parse.Query('AccountStatement')
    .equalTo('userId', userId)
    .descending('createdAt')
    .first({ useMasterKey: true });

  const balanceBefore = lastEntry ? (lastEntry.get('balanceAfter') || 0) : 0;
  const balanceAfter = balanceBefore + amount;

  const entry = new AccountStatement();
  const normalizedTradeNumber = tradeNumber === undefined || tradeNumber === null
    ? ''
    : String(tradeNumber);
  entry.set('userId', userId);
  entry.set('entryType', entryType);
  entry.set('amount', amount);
  entry.set('balanceBefore', round2(balanceBefore));
  entry.set('balanceAfter', round2(balanceAfter));
  entry.set('tradeId', tradeId);
  entry.set('tradeNumber', normalizedTradeNumber);
  if (investmentId) entry.set('investmentId', investmentId);
  const invNumTrim = String(investmentNumber || '').trim();
  if (invNumTrim) entry.set('investmentNumber', invNumTrim);
  const bizRef = composeStatementBusinessReference({
    tradeNumber,
    referenceDocumentNumber,
    investmentNumber: invNumTrim,
  });
  if (bizRef) entry.set('businessReference', bizRef);
  entry.set('description', description);
  if (referenceDocumentId) entry.set('referenceDocumentId', referenceDocumentId);
  if (referenceDocumentNumber) entry.set('referenceDocumentNumber', referenceDocumentNumber);
  const bc = String(businessCaseId || '').trim();
  if (bc) entry.set('businessCaseId', bc);
  entry.set('source', 'backend');

  await entry.save(null, { useMasterKey: true });
  return entry;
}

// ============================================================================
// GL mapping per AccountStatement entryType.
//
// Each rule defines which AppLedgerEntry pair must accompany the
// AccountStatement row. `null` means "no GL pair" (e.g. investment_activate /
// investment_return — those are already covered by investmentEscrow.js
// CLT-LIAB-* shifts; posting another pair would double-book the customer
// liability). `trade_buy` / `trade_sell` are intentionally out of scope for
// Phase 1 (would require an asset account `CLT-AST-TRD` + trustee bank mapping
// `BANK-TRT-CLT`, scheduled for ADR-010 Phase 2 / PR5).
//
// `userRoleForLeg(userRole, entry)`: convenience to keep the booking row's
// userRole in lockstep with the AccountStatement row.
// ============================================================================

const SETTLEMENT_GL_RULES = {
  // Provision: Investor zahlt → Plattform schuldet dem Trader → Trader bekommt Cash.
  // Phase 1: 100% Trader-Cut (PLT-LIAB-COM saldiert pro Trade auf 0).
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

  // Steuern: Plattform zieht ein, schuldet dem Finanzamt.
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

  // Handelsgebühren-Sammelposting (Trader). Wenn die Aufrufseite ein
  // feeBreakdown übergibt, wird stattdessen pro Komponente ein eigenes Pair
  // gebucht (s. bookSettlementEntry). Dieser Default-Eintrag deckt den Fall ab,
  // dass nur ein aggregierter Betrag bekannt ist.
  trading_fees: {
    leg: 'trading_fees',
    transactionType: 'orderFee',
    debitAccount: 'CLT-LIAB-AVA',
    creditAccount: 'PLT-REV-ORD',
  },

  // Residual aus Stückkauf-Rundung: bleibt bis zum Escrow-Release auf TRD und
  // wird dort verrechnet — kein separates Pair nötig.
  residual_return: null,

  // Investment-Aktivierung / -Rückzahlung: bereits durch investmentEscrow.js
  // (CLT-LIAB-RSV/TRD/AVA) abgedeckt. Ein zusätzliches Pair würde doppelt buchen.
  investment_activate: null,
  investment_return: null,
  investment_refund: null,

  // ADR-011 / PR5: Trade-Cash-Pair (Trader Wertpapierkauf/-verkauf via Treuhand-Bank).
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

  // ADR-011 / PR5: Wallet IN/OUT (Bank-Eingang ↔ Kundenverbindlichkeit).
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
 *   When present, one GL pair per non-zero component is written using
 *   `PLT-REV-ORD`/`PLT-REV-EXC`/`PLT-REV-FRG`. The aggregated AccountStatement
 *   row stays a single line for customer-facing display.
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
  ledgerReference, // { referenceId, referenceType } overrides; default: tradeId/'Trade'
  businessCaseId,
  enforceReferenceDocumentId = true,
}) {
  const stmt = await bookAccountStatementEntry({
    userId,
    entryType,
    amount,
    tradeId,
    tradeNumber,
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
      tradeId,
      tradeNumber,
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

  // Order-fee multi-leg: split aggregated amount into component pairs.
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

const ORDER_FEE_COMPONENTS = [
  { key: 'orderFee',     account: 'PLT-REV-ORD', leg: 'order_fee:orderFee',     transactionType: 'orderFee' },
  { key: 'exchangeFee',  account: 'PLT-REV-EXC', leg: 'order_fee:exchangeFee',  transactionType: 'exchangeFee' },
  { key: 'foreignCosts', account: 'PLT-REV-FRG', leg: 'order_fee:foreignCosts', transactionType: 'foreignCosts' },
];

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

function roleFromEntryType(entryType) {
  if (entryType === 'commission_credit' || entryType === 'trading_fees' ||
      entryType === 'trade_buy' || entryType === 'trade_sell') {
    return 'trader';
  }
  // ADR-011: deposit/withdrawal können von Tradern oder Investoren stammen –
  // der Caller (triggers/wallet.js) sollte `userRole` explizit übergeben.
  // Fallback 'user' ist absichtlich neutral, damit die Personenkonten‑Sicht
  // nicht falsch klassifiziert wird, wenn die Rolle fehlt.
  if (entryType === 'deposit' || entryType === 'withdrawal') {
    return 'user';
  }
  return 'investor';
}

module.exports = {
  bookAccountStatementEntry,
  bookSettlementEntry,
  // exported for unit tests / future health checks
  getSettlementGLRule,
  ORDER_FEE_COMPONENTS,
};
