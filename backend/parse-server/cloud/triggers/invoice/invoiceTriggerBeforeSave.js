'use strict';

const { assertNoDuplicateServiceChargeBatch } = require('../invoiceDuplicateGuard');
const { assignInvoiceNumberIfMissingForServiceCharge } = require('../../utils/serviceChargeInvoiceNumber');

async function invoiceBeforeSave(request) {
  await assertNoDuplicateServiceChargeBatch(request.object, Parse);
  await assignInvoiceNumberIfMissingForServiceCharge(request.object, Parse);
}

module.exports = {
  invoiceBeforeSave,
};
