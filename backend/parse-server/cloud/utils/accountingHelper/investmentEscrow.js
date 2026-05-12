'use strict';

/**
 * Client-funds sub-ledger (CLT-LIAB-*): reserve → trading → release.
 * Balanced pairs only; idempotent per investmentId + metadata.leg.
 * See Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md
 */

const { round2 } = require('./shared');
const {
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
} = require('./accountMappingResolver');
const { createInvestmentReservationEigenbelegDocument } = require('./documents');

const TRANSACTION_TYPE = 'investmentEscrow';
const REFERENCE_TYPE = 'Investment';

async function hasEscrowLeg(investmentId, leg) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(100);
  const rows = await q.find({ useMasterKey: true });
  return rows.some((e) => (e.get('metadata') || {}).leg === leg);
}

/**
 * GoB: Folgebuchungen (deploy, release, …) beziehen sich auf denselben Eigenbeleg wie `leg: reserve`.
 * Liest `metadata.referenceDocumentId` / `referenceDocumentNumber` von einer bestehenden Reserve-Zeile.
 */
async function eigenbelegRefFromReserveLeg(investmentId) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(100);
  const rows = await q.find({ useMasterKey: true });
  for (const e of rows) {
    const m = e.get('metadata') || {};
    if (m.leg !== 'reserve') continue;
    const id = String(m.referenceDocumentId || '').trim();
    const num = String(m.referenceDocumentNumber || '').trim();
    if (id && num) {
      return { referenceDocumentId: id, referenceDocumentNumber: num };
    }
  }
  return {};
}

function baseFields(investorId, investmentId, leg, description, extraMeta = {}) {
  const invNum = String(extraMeta.investmentNumber || '').trim();
  const businessReference = invNum ? `Investition ${invNum}` : '';
  return {
    userId: investorId || '',
    userRole: 'investor',
    transactionType: TRANSACTION_TYPE,
    referenceId: investmentId,
    referenceType: REFERENCE_TYPE,
    description,
    metadata: Object.assign({ leg, businessReference }, extraMeta),
  };
}

async function savePair(debitAccount, creditAccount, amount, common) {
  if (amount <= 0) return;
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const d = new AppLedgerEntry();
  d.set('account', debitAccount);
  const debitSnapshot = applyLedgerSnapshotToEntry(d, debitAccount);
  d.set('side', 'debit');
  d.set('amount', amount);
  d.set('userId', common.userId);
  d.set('userRole', common.userRole);
  d.set('transactionType', common.transactionType);
  d.set('referenceId', common.referenceId);
  d.set('referenceType', common.referenceType);
  d.set('description', common.description);
  d.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, { pairedAccount: creditAccount }),
    debitSnapshot,
  ));

  const c = new AppLedgerEntry();
  c.set('account', creditAccount);
  const creditSnapshot = applyLedgerSnapshotToEntry(c, creditAccount);
  c.set('side', 'credit');
  c.set('amount', amount);
  c.set('userId', common.userId);
  c.set('userRole', common.userRole);
  c.set('transactionType', common.transactionType);
  c.set('referenceId', common.referenceId);
  c.set('referenceType', common.referenceType);
  c.set('description', common.description);
  c.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, { pairedAccount: debitAccount }),
    creditSnapshot,
  ));

  await Parse.Object.saveAll([d, c], { useMasterKey: true });
}

/**
 * New investment (reserved): available → reserved
 *
 * GoB: **Erst Beleg, dann Buchung.** Persistierter Eigenbeleg (Document) muss
 * vor dem App-Ledger-Paar existieren; ohne Beleg findet keine Reservierung statt.
 */
async function bookReserve({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  parseInvestment,
}) {
  const amt = round2(amount);
  if (amt <= 0) return { ok: true, skipped: 'non_positive' };

  const objId = parseInvestment && typeof parseInvestment.get === 'function'
    ? (parseInvestment.id || parseInvestment.get('objectId'))
    : null;
  const paramId = investmentId != null ? String(investmentId).trim() : '';
  const resolvedId = String(objId || paramId || '').trim();
  if (!resolvedId) {
    console.error('❌ bookReserve abgebrochen: objectId fehlt — GoB erfordert Eigenbeleg vor Buchung.');
    return { ok: false, reason: 'missing_object_id' };
  }
  if (objId && paramId && String(objId) !== paramId) {
    console.warn(
      `bookReserve: investmentId (${paramId}) weicht von parseInvestment.id (${objId}) ab — nutze ${resolvedId}`,
    );
  }

  if (await hasEscrowLeg(resolvedId, 'reserve')) {
    return { ok: true, skipped: 'already_booked' };
  }

  if (!parseInvestment || typeof parseInvestment.get !== 'function') {
    console.error(
      `❌ bookReserve abgebrochen (${resolvedId}): parseInvestment fehlt — GoB erfordert Eigenbeleg vor Buchung.`,
    );
    return { ok: false, reason: 'missing_parse_investment' };
  }

  let doc;
  try {
    doc = await createInvestmentReservationEigenbelegDocument(parseInvestment);
  } catch (err) {
    console.error(`❌ Eigenbeleg Reservierung fehlgeschlagen, Buchung unterbleibt ${resolvedId}:`, err.message);
    return { ok: false, reason: 'eigenbeleg_failed', detail: err.message };
  }
  if (!doc) {
    console.error(`❌ Eigenbeleg Reservierung nicht erstellbar, Buchung unterbleibt ${resolvedId}`);
    return { ok: false, reason: 'eigenbeleg_null' };
  }

  const desc = `Kundenguthaben reserviert${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${resolvedId}`;
  const docNum = String(doc.get('accountingDocumentNumber') || doc.get('documentNumber') || '').trim();
  const bcReserve = String(parseInvestment.get('businessCaseId') || '').trim();
  await savePair(
    'CLT-LIAB-AVA',
    'CLT-LIAB-RSV',
    amt,
    baseFields(investorId, resolvedId, 'reserve', desc, {
      investmentNumber: investmentNumber || '',
      referenceDocumentId: doc.id,
      referenceDocumentNumber: docNum,
      businessReference: docNum ? `Beleg ${docNum}` : '',
      ...(bcReserve ? { businessCaseId: bcReserve } : {}),
    }),
  );
  return { ok: true };
}

/**
 * reserved → active: reserved → trading
 */
async function bookDeployToTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'deploy')) return;
  const desc = `Kundenguthaben Handel/Pool${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-TRD',
    amt,
    baseFields(investorId, investmentId, 'deploy', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
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
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReserve')) return;
  const desc = `Reservierung aufgelöst${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReserve', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
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
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  const leg = reason === 'refund' ? 'releaseTradingRefund' : 'releaseTradingComplete';
  if (await hasEscrowLeg(investmentId, leg)) return;
  const desc = reason === 'refund'
    ? `Handelsbindung Rückerstattung – Investment ${investmentId}`
    : `Handelsbindung Auflösung (Abschluss) – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-TRD',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, leg, desc, {
      investmentNumber: investmentNumber || '',
      reason: reason || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
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
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReservedComplete')) return;
  const desc = `Reserviert → verfügbar (Abschluss ohne Aktivierungspfad) – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReservedComplete', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

module.exports = {
  bookReserve,
  bookDeployToTrading,
  bookReleaseReservation,
  bookReleaseTrading,
  bookReleaseReservedOnComplete,
  hasEscrowLeg,
  TRANSACTION_TYPE,
};
