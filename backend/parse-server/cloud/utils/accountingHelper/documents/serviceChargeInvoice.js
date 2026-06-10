'use strict';

const { isServiceChargeInvoiceType } = require('../../serviceChargeInvoiceTypes');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { applyBusinessCaseIdToDocument, formatEuroDe, formatDateTimeDe } = require('./shared');

/**
 * GoB / Admin: one Parse `Document` per service-/app-service-charge invoice,
 * using the same `accountingDocumentNumber` as `Invoice.invoiceNumber`
 * so AppLedger `referenceDocumentId` resolves without number-only heuristics.
 *
 * Runs after the `Invoice` row exists (afterSave path); companion `Document` is
 * not in the same DB transaction as the invoice — idempotent create + stable
 * keys avoid duplicate Belege if the trigger retries.
 */
async function ensureServiceChargeInvoiceDocument(invoice) {
  const invoiceType = String(invoice.get('invoiceType') || '');
  if (!isServiceChargeInvoiceType(invoiceType)) {
    return null;
  }
  const invoiceNumber = String(invoice.get('invoiceNumber') || '').trim();
  if (!invoiceNumber || !invoice.id) {
    return null;
  }
  const userId = String(invoice.get('userId') || invoice.get('customerId') || '').trim();
  if (!userId) {
    return null;
  }

  const Document = Parse.Object.extend('Document');
  const bySource = new Parse.Query(Document);
  bySource.equalTo('metadata.sourceInvoiceId', invoice.id);
  const byNumber = new Parse.Query(Document);
  byNumber.equalTo('accountingDocumentNumber', invoiceNumber);
  byNumber.equalTo('userId', userId);
  const combined = Parse.Query.or(bySource, byNumber);
  combined.limit(5);
  const candidates = await combined.find({ useMasterKey: true });

  let doc = null;
  if (candidates.length > 0) {
    doc = candidates.find((d) => String((d.get('metadata') || {}).sourceInvoiceId || '') === invoice.id)
      || candidates.find((d) => String(d.get('accountingDocumentNumber') || '').trim() === invoiceNumber)
      || candidates[0];
  }
  if (doc) {
    const m = doc.get('metadata') || {};
    if (!m.sourceInvoiceId) {
      doc.set('metadata', Object.assign({}, m, { sourceInvoiceId: invoice.id }));
      await doc.save(null, { useMasterKey: true });
    }
    return doc;
  }

  const batchId = String(invoice.get('batchId') || '').trim();
  const investmentId = String(invoice.get('investmentId') || '').trim();
  const netAmount = round2(Number(invoice.get('subtotal')) || 0);
  const vatAmount = round2(Number(invoice.get('taxAmount')) || 0);
  const totalRaw = Number(invoice.get('totalAmount'));
  const totalAmount = Number.isFinite(totalRaw) && totalRaw > 0
    ? round2(totalRaw)
    : round2(netAmount + vatAmount);
  const belegDatum = invoice.get('createdAt') || new Date();
  const dateStr = formatDateCompact(belegDatum);
  const hash = generateShortHash();

  const accountingSummaryText = [
    `App-Service-Rechnung ${invoiceNumber}`,
    `Kunde: ${userId}`,
    batchId ? `Batch: ${batchId}` : null,
    `Rechnungsart: ${invoiceType}`,
    `Netto: ${formatEuroDe(netAmount)}`,
    `USt: ${formatEuroDe(vatAmount)}`,
    `Brutto: ${formatEuroDe(totalAmount)}`,
    `Belegdatum: ${formatDateTimeDe(belegDatum)}`,
    `Parse Invoice objectId: ${invoice.id}`,
  ].filter(Boolean).join('\n');

  const newDoc = new Document();
  newDoc.set('userId', userId);
  newDoc.set('type', 'invoice');
  newDoc.set('name', `Invoice_${invoiceNumber}_${dateStr}_${hash}.pdf`);
  newDoc.set('accountingDocumentNumber', invoiceNumber);
  newDoc.set('documentNumber', invoiceNumber);
  newDoc.set('source', 'backend');
  newDoc.set('status', 'verified');
  newDoc.set('fileURL', `invoice-beleg://${invoiceNumber}.pdf`);
  newDoc.set('accountingSummaryText', accountingSummaryText);
  newDoc.set('size', Buffer.byteLength(accountingSummaryText, 'utf8'));
  newDoc.set('metadata', {
    sourceInvoiceId: invoice.id,
    invoiceType,
    batchId: batchId || null,
    invoiceNumber,
    netAmount,
    vatAmount,
    totalAmount,
    generatedAt: new Date().toISOString(),
    adrRef: 'ADR-007',
  });
  if (investmentId) {
    newDoc.set('investmentId', investmentId);
  }

  applyBusinessCaseIdToDocument(newDoc, invoice.get('businessCaseId'));

  await newDoc.save(null, { useMasterKey: true });
  console.log(`📄 Service-charge invoice document: ${invoiceNumber} (invoice ${invoice.id})`);
  return newDoc;
}

async function resolveDocumentRefsFromInvoiceIfOwned(invoice, expectedUserId, expectedGross) {
  const uid = String(expectedUserId || '').trim();
  const invUser = String(invoice.get('userId') || invoice.get('customerId') || '').trim();
  if (!uid || invUser !== uid) {
    return {};
  }
  const invType = String(invoice.get('invoiceType') || '');
  if (!isServiceChargeInvoiceType(invType)) {
    return {};
  }
  const totalRaw = Number(invoice.get('totalAmount'));
  const sub = round2(Number(invoice.get('subtotal')) || 0);
  const tax = round2(Number(invoice.get('taxAmount')) || 0);
  const total = Number.isFinite(totalRaw) && totalRaw > 0
    ? round2(totalRaw)
    : round2(sub + tax);
  const expected = round2(Number(expectedGross));
  if (!Number.isFinite(expected) || expected <= 0 || total !== expected) {
    return {};
  }
  const doc = await ensureServiceChargeInvoiceDocument(invoice);
  const refId = doc && doc.id ? String(doc.id).trim() : '';
  const refNo = String(invoice.get('invoiceNumber') || '').trim();
  return {
    ...(refId ? { referenceDocumentId: refId } : {}),
    ...(refNo ? { referenceDocumentNumber: refNo } : {}),
  };
}

module.exports = {
  ensureServiceChargeInvoiceDocument,
  resolveDocumentRefsFromInvoiceIfOwned,
};
