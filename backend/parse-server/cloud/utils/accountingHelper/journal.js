'use strict';

// ============================================================================
// Generic double-entry journal helper for AppLedgerEntry.
//
// Used by trade settlement, invoice triggers, and any future flow that needs to
// post a balanced (debit + credit) pair on top of a Personenkonto/AccountStatement
// row.
//
// Contract:
//   - Writes EXACTLY two AppLedgerEntry rows in one Parse.Object.saveAll call.
//   - Both rows share `transactionType`, `referenceId`, `referenceType`,
//     `description`, `userRole`, and a deterministic `metadata.leg` so the
//     idempotency probe (`hasLeg`) can cheaply detect re-runs.
//   - Mapping snapshot (`accountMappingResolver.applyLedgerSnapshotToEntry`) is
//     applied per side so each row carries a self-contained SKR/VAT-key trace.
//   - Fail-open philosophy: if a GL pair fails the caller (`bookSettlementEntry`)
//     logs and continues — the AccountStatement row stays the source of truth
//     for customer balances. The mismatch will surface in the App Ledger health
//     report (PR4 follow-up) instead of breaking checkout/settlement flows.
//
// See:
//   - Documentation/ADR-010-Settlement-GL-Posting.md
//   - Documentation/LEDGER_CHART_OF_ACCOUNTS_ROADMAP.md (PR4)
//   - Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md § 4
// ============================================================================

const { round2 } = require('./shared');
const {
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
} = require('./accountMappingResolver');

/**
 * Returns true if a balanced pair with the same `(referenceId, referenceType,
 * transactionType, metadata.leg)` already exists. Designed to short-circuit
 * re-runs cheaply (LIMIT=8 is plenty: a leg is at most two rows, and we tolerate
 * a few unrelated `metadata.leg` values for the same reference).
 */
async function hasLeg({ referenceId, referenceType, transactionType, leg }) {
  if (!referenceId || !leg) return false;
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', referenceId);
  if (referenceType) q.equalTo('referenceType', referenceType);
  if (transactionType) q.equalTo('transactionType', transactionType);
  q.limit(8);
  const rows = await q.find({ useMasterKey: true });
  return rows.some((row) => {
    const md = row.get('metadata') || {};
    return md.leg === leg;
  });
}

/**
 * Posts a single balanced double-entry pair on AppLedgerEntry.
 *
 * Returns:
 *   - [debitEntry, creditEntry] when the pair is written.
 *   - [] when the pair was skipped (amount <= 0 or duplicate via `leg`).
 *
 * `leg` is REQUIRED for idempotency. Choose deterministic strings such as:
 *   - 'commission'                         (settlement.js)
 *   - 'withholding_tax'                    (settlement.js)
 *   - 'order_fee:orderFee'                 (invoice.js)
 *   - 'order_fee:exchangeFee'              (invoice.js)
 *   - 'order_fee:foreignCosts'             (invoice.js)
 */
async function postLedgerPair({
  debitAccount,
  creditAccount,
  amount,
  userId,
  userRole,
  transactionType,
  referenceId,
  referenceType,
  description,
  metadata = {},
  leg,
}) {
  const amt = round2(Math.abs(Number(amount) || 0));
  if (amt <= 0) return [];
  if (!debitAccount || !creditAccount) return [];
  if (!leg) {
    throw new Error('postLedgerPair: `leg` is required for idempotency');
  }

  if (await hasLeg({ referenceId, referenceType, transactionType, leg })) {
    return [];
  }

  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const baseMetadata = Object.assign({ leg }, metadata);

  const debit = new AppLedgerEntry();
  debit.set('account', debitAccount);
  const debitSnap = applyLedgerSnapshotToEntry(debit, debitAccount);
  debit.set('side', 'debit');
  debit.set('amount', amt);
  debit.set('userId', userId || '');
  debit.set('userRole', userRole || '');
  debit.set('transactionType', transactionType);
  debit.set('referenceId', referenceId);
  if (referenceType) debit.set('referenceType', referenceType);
  if (description) debit.set('description', description);
  debit.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, baseMetadata, { pairedAccount: creditAccount }),
    debitSnap,
  ));

  const credit = new AppLedgerEntry();
  credit.set('account', creditAccount);
  const creditSnap = applyLedgerSnapshotToEntry(credit, creditAccount);
  credit.set('side', 'credit');
  credit.set('amount', amt);
  credit.set('userId', userId || '');
  credit.set('userRole', userRole || '');
  credit.set('transactionType', transactionType);
  credit.set('referenceId', referenceId);
  if (referenceType) credit.set('referenceType', referenceType);
  if (description) credit.set('description', description);
  credit.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, baseMetadata, { pairedAccount: debitAccount }),
    creditSnap,
  ));

  await Parse.Object.saveAll([debit, credit], { useMasterKey: true });
  return [debit, credit];
}

module.exports = {
  hasLeg,
  postLedgerPair,
};
