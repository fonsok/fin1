'use strict';

const {
  isServiceChargeInvoiceType,
  serviceChargeInvoiceTypesForDuplicateQuery,
} = require('../utils/serviceChargeInvoiceTypes');

/**
 * ADR-007 / Invoice SSOT: blocks a second Parse `Invoice` for the same
 * service-charge source.
 *
 * Prevents double BankContra + AppLedger when the client retries the legacy
 * `addInvoice` path after the server already persisted `bookAppServiceCharge`.
 *
 * Primary key is (`invoiceType`, `batchId`) because one service-charge Beleg
 * represents the completed business case for the full investment batch.
 * Legacy fallback is (`invoiceType`, `investmentId`) only when no `batchId`
 * is available.
 *
 * @param {Parse.Object} invoice
 * @param {typeof Parse} Parse
 */
async function assertNoDuplicateServiceChargeBatch(invoice, Parse) {
  const invoiceType = invoice.get('invoiceType') || '';
  if (!isServiceChargeInvoiceType(invoiceType)) {
    return;
  }

  const rawBatchId = invoice.get('batchId');
  let matchField = '';
  let matchValue = '';
  if (typeof rawBatchId === 'string' && rawBatchId.trim()) {
    matchField = 'batchId';
    matchValue = rawBatchId.trim();
  } else {
    const investmentId = invoice.get('investmentId');
    if (typeof investmentId !== 'string' || !investmentId.trim()) {
      return;
    }
    matchField = 'investmentId';
    matchValue = investmentId.trim();
  }

  const query = new Parse.Query('Invoice');
  query.containedIn('invoiceType', serviceChargeInvoiceTypesForDuplicateQuery());
  query.equalTo(matchField, matchValue);
  const currentId = invoice.id;
  if (currentId) {
    query.notEqualTo('objectId', currentId);
  }

  const duplicate = await query.first({ useMasterKey: true });
  if (duplicate) {
    throw new Parse.Error(
      Parse.Error.DUPLICATE_VALUE,
      'Eine Servicegebühren-Rechnung existiert bereits für diesen Investment-Batch.'
    );
  }
}

module.exports = { assertNoDuplicateServiceChargeBatch };
