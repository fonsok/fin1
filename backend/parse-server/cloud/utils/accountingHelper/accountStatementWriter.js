'use strict';

/**
 * AccountStatement (Personenkonto / Sub-Ledger) writer — single-row contract.
 *
 * `balanceBefore` / `balanceAfter` come from Phase 3b (`userCashBalanceAtomic.js`)
 * via Mongo `$inc` + pre-image, not from read-modify-write on the last statement row.
 * On failed `AccountStatement.save`, the `$inc` is compensated.
 *
 * See `settlementGLPoster.js` for `bookSettlementEntry` (statement + GL pair).
 */

const { normalizeEuro } = require('./moneyCents');
const { auditChainConsistencyOnInsert } = require('./accountStatementChainGuard');
const {
  advanceUserCashBalanceAtomic,
  compensateUserCashBalanceAdvance,
} = require('./userCashBalanceAtomic');
const { audit } = require('../structuredLogger');

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
  customerDisplaySnapshot,
  enforceReferenceDocumentId = true,
  glOutboxPayload = null,
}) {
  if (enforceReferenceDocumentId && (!referenceDocumentId || !referenceDocumentNumber)) {
    throw new Error(
      `GoB violation blocked: AccountStatement booking requires referenceDocumentId + referenceDocumentNumber (entryType=${entryType}, userId=${userId}, tradeId=${tradeId || ''}, investmentId=${investmentId || ''})`,
    );
  }

  const normalizedAmount = normalizeEuro(amount);

  const AccountStatement = Parse.Object.extend('AccountStatement');

  let balanceBefore;
  let balanceAfter;
  try {
    ({ balanceBefore, balanceAfter } = await advanceUserCashBalanceAtomic({
      userId,
      amount: normalizedAmount,
    }));
  } catch (err) {
    audit.error('accountstatement.balance.advanceFailure', {
      userId,
      entryType,
      amount: normalizedAmount,
      tradeId: tradeId || null,
      investmentId: investmentId || null,
      businessCaseId: String(businessCaseId || '').trim() || null,
      error: err && err.message ? err.message : String(err),
      message: 'bookAccountStatementEntry: advanceUserCashBalanceAtomic failed',
    });
    throw err;
  }

  const entry = new AccountStatement();
  const normalizedTradeNumber = tradeNumber === undefined || tradeNumber === null
    ? ''
    : String(tradeNumber);
  entry.set('userId', userId);
  entry.set('entryType', entryType);
  entry.set('amount', normalizedAmount);
  entry.set('balanceBefore', balanceBefore);
  entry.set('balanceAfter', balanceAfter);
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
  if (customerDisplaySnapshot && typeof customerDisplaySnapshot === 'object') {
    entry.set('customerDisplaySnapshot', customerDisplaySnapshot);
  }
  entry.set('source', 'backend');

  try {
    if (glOutboxPayload) {
      const { saveAccountStatementWithOutbox } = require('./settlementOutbox');
      await saveAccountStatementWithOutbox(entry, glOutboxPayload);
    } else {
      await entry.save(null, { useMasterKey: true });
    }
  } catch (saveErr) {
    const rolledBack = await compensateUserCashBalanceAdvance({ userId, amount: normalizedAmount });
    if (rolledBack) {
      audit.warn('accountstatement.balance.advanceRollback', {
        userId,
        entryType,
        amount: normalizedAmount,
        tradeId: tradeId || null,
        investmentId: investmentId || null,
        businessCaseId: bc || null,
        error: saveErr && saveErr.message ? saveErr.message : String(saveErr),
        message: 'bookAccountStatementEntry: AccountStatement save failed; UserCashBalance compensated',
      });
    } else {
      audit.error('accountstatement.balance.advanceRollbackCritical', {
        userId,
        entryType,
        amount: normalizedAmount,
        tradeId: tradeId || null,
        investmentId: investmentId || null,
        businessCaseId: bc || null,
        saveError: saveErr && saveErr.message ? saveErr.message : String(saveErr),
        message: 'bookAccountStatementEntry: save failed AND compensate failed — manual repair required',
      });
    }
    throw saveErr;
  }

  await auditChainConsistencyOnInsert({
    userId,
    insertedEntry: entry,
    entryType,
    amount: normalizedAmount,
    tradeId,
    tradeNumber,
    investmentId,
    investmentNumber: invNumTrim,
    businessCaseId: bc,
  });

  return entry;
}

module.exports = {
  composeStatementBusinessReference,
  bookAccountStatementEntry,
};
