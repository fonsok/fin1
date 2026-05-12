'use strict';

/**
 * Invoice rows that share the ADR-007 service-charge ledger path (beforeSave
 * numbering, duplicate guard, afterSave postings, Document companion).
 *
 * `app_service_charge` is the preferred name; `platform_service_charge` is
 * legacy Parse/iOS data and remains readable everywhere.
 */
const SERVICE_CHARGE_INVOICE_TYPES = Object.freeze([
  'service_charge',
  'app_service_charge',
  'platform_service_charge',
]);

const SERVICE_CHARGE_TYPE_SET = new Set(SERVICE_CHARGE_INVOICE_TYPES);

function isServiceChargeInvoiceType(invoiceType) {
  return SERVICE_CHARGE_TYPE_SET.has(String(invoiceType || ''));
}

/** For duplicate guard: any of these types blocks the same batch twice. */
function serviceChargeInvoiceTypesForDuplicateQuery() {
  return [...SERVICE_CHARGE_INVOICE_TYPES];
}

module.exports = {
  SERVICE_CHARGE_INVOICE_TYPES,
  isServiceChargeInvoiceType,
  serviceChargeInvoiceTypesForDuplicateQuery,
};
