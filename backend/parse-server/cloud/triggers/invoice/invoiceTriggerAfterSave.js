'use strict';

const { isServiceChargeInvoiceType } = require('../../utils/serviceChargeInvoiceTypes');
const { postOrderInvoiceFees } = require('./invoiceOrderFeePosting');
const { postServiceChargeInvoiceLedger } = require('./invoiceServiceChargePosting');

async function invoiceAfterSave(request) {
  const invoice = request.object;
  const isNew = !request.original;

  if (!isNew) {
    const oldType = request.original.get('invoiceType');
    const newType = invoice.get('invoiceType');
    if (oldType === newType) {
      return;
    }
  }

  const invoiceType = invoice.get('invoiceType') || '';

  if (invoiceType === 'order') {
    try {
      await postOrderInvoiceFees(invoice);
    } catch (err) {
      console.error('afterSave Invoice (order fees): failed to post AppLedger pairs:', err.message);
    }
    return;
  }

  if (!isServiceChargeInvoiceType(invoiceType)) {
    return;
  }

  try {
    await postServiceChargeInvoiceLedger(invoice);
  } catch (err) {
    console.error('afterSave Invoice: failed to create BankContraPosting/AppLedgerEntry:', err.message);
  }
}

module.exports = {
  invoiceAfterSave,
};
