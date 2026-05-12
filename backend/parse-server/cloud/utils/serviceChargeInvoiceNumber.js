'use strict';

const { isServiceChargeInvoiceType } = require('./serviceChargeInvoiceTypes');

/**
 * Assigns a sequential server-side invoice number for service_charge invoices
 * when none was provided (ADR-007 bookAppServiceCharge path). GoB / audit: every
 * charge receipt must have a stable business key before ledger posting.
 */
async function getNextServiceChargeInvoiceNumber(Parse) {
  const year = new Date().getFullYear();
  const startsWithPattern = `SC-${year}-`;
  const q = new Parse.Query('Invoice');
  q.startsWith('invoiceNumber', startsWithPattern);
  q.descending('invoiceNumber');
  const last = await q.first({ useMasterKey: true });
  let seq = 1;
  if (last) {
    const parts = String(last.get('invoiceNumber') || '').split('-');
    const lastSeq = parseInt(parts[2], 10);
    if (Number.isFinite(lastSeq)) seq = lastSeq + 1;
  }
  return `SC-${year}-${seq.toString().padStart(7, '0')}`;
}

async function assignInvoiceNumberIfMissingForServiceCharge(invoice, Parse) {
  const type = String(invoice.get('invoiceType') || '');
  if (!isServiceChargeInvoiceType(type)) {
    return;
  }
  const existing = String(invoice.get('invoiceNumber') || '').trim();
  if (existing) return;
  const next = await getNextServiceChargeInvoiceNumber(Parse);
  invoice.set('invoiceNumber', next);
}

module.exports = {
  getNextServiceChargeInvoiceNumber,
  assignInvoiceNumberIfMissingForServiceCharge,
};
