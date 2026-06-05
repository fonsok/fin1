'use strict';

/**
 * Detection-only chain-consistency guard for `AccountStatement` rows.
 *
 * Background (historisch): Vor Phase 3b las `bookAccountStatementEntry` das letzte
 * `AccountStatement` per Read-Modify-Write — bei parallelen Buchungen für denselben
 * `userId` konnte die Kette brechen. **Phase 3b** linearisiert die Salden über
 * `UserCashBalance` + Mongo `$inc` (`userCashBalanceAtomic.js`); dieser Guard bleibt
 * als zusätzliche Plausibilitätsprüfung (Drift, manuelle DB-Eingriffe, fehlgeschlagene
 * Kompensation) sinnvoll.
 *
 * Wir detektieren nach jedem Insert und emittieren ein strukturiertes Audit-Event.
 *
 * The guard is best-effort: it runs after the row was saved (so the customer
 * balance is already authoritative) and never throws into the booking path —
 * any failure is logged via `audit.error` and swallowed.
 */

const { audit } = require('../structuredLogger');

const FLOAT_TOLERANCE = 0.005;

async function auditChainConsistencyOnInsert({
  userId,
  insertedEntry,
  entryType,
  amount,
  tradeId,
  tradeNumber,
  investmentId,
  investmentNumber,
  businessCaseId,
}) {
  if (!userId || !insertedEntry || !insertedEntry.id) return;

  try {
    const recent = await new Parse.Query('AccountStatement')
      .equalTo('userId', userId)
      .descending('createdAt')
      .limit(2)
      .find({ useMasterKey: true });

    if (!Array.isArray(recent) || recent.length === 0) return;

    const newest = recent[0];
    // Another concurrent write inserted a row after ours — the next call's
    // guard run will surface the break, no need to claim authority here.
    if (newest.id !== insertedEntry.id) return;

    if (recent.length < 2) return;
    const previous = recent[1];

    const previousAfter = Number(previous.get('balanceAfter') || 0);
    const newestBefore = Number(newest.get('balanceBefore') || 0);
    const delta = Number((newestBefore - previousAfter).toFixed(4));
    if (Math.abs(delta) <= FLOAT_TOLERANCE) return;

    audit.warn('accountstatement.balance.chainBreak', {
      userId,
      newestEntryId: newest.id,
      previousEntryId: previous.id,
      entryType: entryType || newest.get('entryType') || null,
      amount: Number.isFinite(amount) ? amount : null,
      tradeId: tradeId || newest.get('tradeId') || null,
      tradeNumber: tradeNumber != null && tradeNumber !== '' ? tradeNumber : null,
      investmentId: investmentId || newest.get('investmentId') || null,
      investmentNumber: investmentNumber || newest.get('investmentNumber') || null,
      businessCaseId: businessCaseId || newest.get('businessCaseId') || null,
      previousBalanceAfter: previousAfter,
      newestBalanceBefore: newestBefore,
      newestBalanceAfter: Number(newest.get('balanceAfter') || 0),
      delta,
      message: 'AccountStatement chain break detected (race candidate)',
    });
  } catch (err) {
    audit.error('accountstatement.balance.chainBreak.guardFailure', {
      userId,
      insertedEntryId: insertedEntry && insertedEntry.id,
      error: err && err.message ? err.message : String(err),
      message: 'auditChainConsistencyOnInsert failed (detection only)',
    });
  }
}

module.exports = {
  auditChainConsistencyOnInsert,
  FLOAT_TOLERANCE,
};
