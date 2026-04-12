'use strict';

/**
 * Client-funds sub-ledger (CLT-LIAB-*): reserve → trading → release.
 * Balanced pairs only; idempotent per investmentId + metadata.leg.
 * See Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md
 */

const { round2 } = require('./shared');

const TRANSACTION_TYPE = 'investmentEscrow';
const REFERENCE_TYPE = 'Investment';

async function hasEscrowLeg(investmentId, leg) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.equalTo('referenceType', REFERENCE_TYPE);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(100);
  const rows = await q.find({ useMasterKey: true });
  return rows.some((e) => (e.get('metadata') || {}).leg === leg);
}

function baseFields(investorId, investmentId, leg, description, extraMeta = {}) {
  return {
    userId: investorId || '',
    userRole: 'investor',
    transactionType: TRANSACTION_TYPE,
    referenceId: investmentId,
    referenceType: REFERENCE_TYPE,
    description,
    metadata: Object.assign({ leg }, extraMeta),
  };
}

async function savePair(debitAccount, creditAccount, amount, common) {
  if (amount <= 0) return;
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const d = new AppLedgerEntry();
  d.set('account', debitAccount);
  d.set('side', 'debit');
  d.set('amount', amount);
  d.set('userId', common.userId);
  d.set('userRole', common.userRole);
  d.set('transactionType', common.transactionType);
  d.set('referenceId', common.referenceId);
  d.set('referenceType', common.referenceType);
  d.set('description', common.description);
  d.set('metadata', common.metadata);

  const c = new AppLedgerEntry();
  c.set('account', creditAccount);
  c.set('side', 'credit');
  c.set('amount', amount);
  c.set('userId', common.userId);
  c.set('userRole', common.userRole);
  c.set('transactionType', common.transactionType);
  c.set('referenceId', common.referenceId);
  c.set('referenceType', common.referenceType);
  c.set('description', common.description);
  c.set('metadata', common.metadata);

  await Parse.Object.saveAll([d, c], { useMasterKey: true });
}

/**
 * New investment (reserved): available → reserved
 */
async function bookReserve({
  investorId,
  amount,
  investmentId,
  investmentNumber,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'reserve')) return;
  const desc = `Kundenguthaben reserviert${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  await savePair(
    'CLT-LIAB-AVA',
    'CLT-LIAB-RSV',
    amt,
    baseFields(investorId, investmentId, 'reserve', desc, { investmentNumber: investmentNumber || '' }),
  );
}

/**
 * reserved → active: reserved → trading
 */
async function bookDeployToTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'deploy')) return;
  const desc = `Kundenguthaben Handel/Pool${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-TRD',
    amt,
    baseFields(investorId, investmentId, 'deploy', desc, { investmentNumber: investmentNumber || '' }),
  );
}

/**
 * reserved → cancelled (user storno): reserved → available
 */
async function bookReleaseReservation({
  investorId,
  amount,
  investmentId,
  investmentNumber,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReserve')) return;
  const desc = `Reservierung aufgelöst${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReserve', desc, { investmentNumber: investmentNumber || '' }),
  );
}

/**
 * Trading / pool → available (completion or refund after active)
 */
async function bookReleaseTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  reason,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  const leg = reason === 'refund' ? 'releaseTradingRefund' : 'releaseTradingComplete';
  if (await hasEscrowLeg(investmentId, leg)) return;
  const desc = reason === 'refund'
    ? `Handelsbindung Rückerstattung – Investment ${investmentId}`
    : `Handelsbindung Auflösung (Abschluss) – Investment ${investmentId}`;
  await savePair(
    'CLT-LIAB-TRD',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, leg, desc, { investmentNumber: investmentNumber || '', reason: reason || '' }),
  );
}

/**
 * reserved → completed (no activate): reserved → available
 */
async function bookReleaseReservedOnComplete({
  investorId,
  amount,
  investmentId,
  investmentNumber,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReservedComplete')) return;
  const desc = `Reserviert → verfügbar (Abschluss ohne Aktivierungspfad) – Investment ${investmentId}`;
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReservedComplete', desc, { investmentNumber: investmentNumber || '' }),
  );
}

module.exports = {
  bookReserve,
  bookDeployToTrading,
  bookReleaseReservation,
  bookReleaseTrading,
  bookReleaseReservedOnComplete,
  TRANSACTION_TYPE,
};
