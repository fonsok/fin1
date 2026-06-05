'use strict';

/**
 * Admin-only: verify `AccountStatement` running-balance chain for one `userId`.
 *
 * Loads all rows in chronological order (`createdAt`, then `objectId`) and checks:
 *   1) Per row: `balanceAfter ≈ balanceBefore + amount` (cent tolerance).
 *   2) Between rows: `row[i].balanceBefore ≈ row[i-1].balanceAfter` (race / gap detection).
 *   3) Global: `last.balanceAfter ≈ first.balanceBefore + sum(amount)` (sanity).
 *
 * Read-only — no mutations.
 */

const { round2 } = require('../../utils/accountingHelper/shared');
const { audit } = require('../../utils/structuredLogger');

const FLOAT_TOLERANCE = 0.005;
const BATCH_SIZE = 1000;

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : NaN;
}

/**
 * @param {Array<{ objectId: string, balanceBefore: number, balanceAfter: number, amount: number, entryType?: string, createdAt?: string|Date }>} entries
 *   Chronological order (oldest first).
 */
function verifyAccountStatementChainRows(entries) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return {
      entryCount: 0,
      chainBreakCount: 0,
      arithmeticBreakCount: 0,
      validChain: true,
      firstChainBreak: null,
      firstArithmeticBreak: null,
      chainBreaksPreview: [],
      arithmeticBreaksPreview: [],
      firstBalanceBefore: null,
      lastBalanceAfter: null,
      sumAmount: 0,
      impliedClosingFromSum: 0,
      sumMatchesLastClosing: true,
    };
  }

  const chainBreaks = [];
  const arithmeticBreaks = [];
  let sumAmount = 0;
  let prevBalanceAfter = null;
  let prevObjectId = null;

  for (let i = 0; i < entries.length; i += 1) {
    const e = entries[i];
    const objectId = String(e.objectId || '').trim() || null;
    const bb = num(e.balanceBefore);
    const ba = num(e.balanceAfter);
    const amt = num(e.amount);

    if (!Number.isFinite(bb) || !Number.isFinite(ba) || !Number.isFinite(amt)) {
      arithmeticBreaks.push({
        index: i,
        objectId,
        reason: 'non_finite_numeric',
        balanceBefore: e.balanceBefore,
        balanceAfter: e.balanceAfter,
        amount: e.amount,
      });
      if (i > 0 && prevBalanceAfter !== null && Number.isFinite(prevBalanceAfter) && Number.isFinite(bb)) {
        if (Math.abs(bb - prevBalanceAfter) > FLOAT_TOLERANCE) {
          chainBreaks.push({
            index: i,
            objectId,
            previousObjectId: prevObjectId,
            expectedBalanceBefore: round2(prevBalanceAfter),
            actualBalanceBefore: round2(bb),
            delta: round2(bb - prevBalanceAfter),
            entryType: e.entryType || null,
          });
        }
      }
      prevBalanceAfter = Number.isFinite(ba) ? ba : null;
      prevObjectId = objectId;
      continue;
    }

    sumAmount += amt;

    if (Math.abs(ba - bb - amt) > FLOAT_TOLERANCE) {
      arithmeticBreaks.push({
        index: i,
        objectId,
        reason: 'balance_after_mismatch',
        balanceBefore: round2(bb),
        balanceAfter: round2(ba),
        amount: round2(amt),
        expectedBalanceAfter: round2(bb + amt),
        delta: round2(ba - (bb + amt)),
      });
    }

    if (i > 0 && prevBalanceAfter !== null && Number.isFinite(prevBalanceAfter)) {
      if (Math.abs(bb - prevBalanceAfter) > FLOAT_TOLERANCE) {
        chainBreaks.push({
          index: i,
          objectId,
          previousObjectId: prevObjectId,
          expectedBalanceBefore: round2(prevBalanceAfter),
          actualBalanceBefore: round2(bb),
          delta: round2(bb - prevBalanceAfter),
          entryType: e.entryType || null,
        });
      }
    }

    prevBalanceAfter = ba;
    prevObjectId = objectId;
  }

  const firstOpening = num(entries[0].balanceBefore);
  const lastClosing = num(entries[entries.length - 1].balanceAfter);
  const impliedClosing = (Number.isFinite(firstOpening) ? firstOpening : 0) + sumAmount;
  const sumCheckDelta = Number.isFinite(lastClosing) && Number.isFinite(impliedClosing)
    ? Math.abs(lastClosing - impliedClosing)
    : Infinity;

  return {
    entryCount: entries.length,
    chainBreakCount: chainBreaks.length,
    arithmeticBreakCount: arithmeticBreaks.length,
    validChain: chainBreaks.length === 0 && arithmeticBreaks.length === 0,
    firstChainBreak: chainBreaks[0] || null,
    firstArithmeticBreak: arithmeticBreaks[0] || null,
    chainBreaksPreview: chainBreaks.slice(0, 10),
    arithmeticBreaksPreview: arithmeticBreaks.slice(0, 10),
    firstBalanceBefore: Number.isFinite(firstOpening) ? round2(firstOpening) : null,
    lastBalanceAfter: Number.isFinite(lastClosing) ? round2(lastClosing) : null,
    sumAmount: round2(sumAmount),
    impliedClosingFromSum: round2(impliedClosing),
    sumMatchesLastClosing: sumCheckDelta <= FLOAT_TOLERANCE,
    sumCheckDelta: round2(sumCheckDelta),
  };
}

async function loadAllAccountStatementsForUser(userId) {
  const out = [];
  let skip = 0;
  for (;;) {
    const q = new Parse.Query('AccountStatement');
    q.equalTo('userId', userId);
    q.ascending('createdAt');
    q.addAscending('objectId');
    q.limit(BATCH_SIZE);
    q.skip(skip);
    // eslint-disable-next-line no-await-in-loop
    const batch = await q.find({ useMasterKey: true });
    if (!batch.length) break;
    out.push(...batch);
    if (batch.length < BATCH_SIZE) break;
    skip += BATCH_SIZE;
  }
  return out;
}

function rowToEntry(row) {
  return {
    objectId: row.id,
    createdAt: row.get('createdAt') || null,
    entryType: row.get('entryType') || null,
    balanceBefore: row.get('balanceBefore'),
    balanceAfter: row.get('balanceAfter'),
    amount: row.get('amount'),
    tradeId: row.get('tradeId') || null,
    investmentId: row.get('investmentId') || null,
  };
}

async function handleVerifyAccountStatementChain(request) {
  const userId = String(request.params?.userId || '').trim();
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId is required');
  }

  const rows = await loadAllAccountStatementsForUser(userId);
  const entries = rows.map(rowToEntry);

  const result = verifyAccountStatementChainRows(entries);

  audit.info('admin.accountstatement.verifyChain', {
    userId,
    entryCount: result.entryCount,
    validChain: result.validChain,
    chainBreakCount: result.chainBreakCount,
    arithmeticBreakCount: result.arithmeticBreakCount,
    sumMatchesLastClosing: result.sumMatchesLastClosing,
    message: 'verifyAccountStatementChain completed',
  });

  return {
    userId,
    ...result,
  };
}

module.exports = {
  FLOAT_TOLERANCE,
  verifyAccountStatementChainRows,
  handleVerifyAccountStatementChain,
  loadAllAccountStatementsForUser,
  rowToEntry,
};
