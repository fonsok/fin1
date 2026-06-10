'use strict';

const { round2 } = require('../shared');
const { createInvestmentReservationEigenbelegDocument } = require('../documents');
const { hasEscrowLeg } = require('./ledgerQueries');
const { baseFields, savePair } = require('./ledgerBuilders');

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

module.exports = {
  bookReserve,
};
