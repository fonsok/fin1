'use strict';

const { round2 } = require('../../utils/accountingHelper/shared');
const {
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
} = require('../../utils/accountingHelper/accountMappingResolver');
const { ensureServiceChargeInvoiceDocument } = require('../../utils/accountingHelper/documents');

/**
 * Service-charge / app_service_charge (legacy: platform_service_charge):
 * BankContraPosting (net + VAT) + AppLedger triple.
 */
async function postServiceChargeInvoiceLedger(invoice) {
  const transactionType = 'appServiceCharge';

  const BankContraPosting = Parse.Object.extend('BankContraPosting');

  const totalAmountRaw = Number(invoice.get('totalAmount'));
  const subtotalRaw = Number(invoice.get('subtotal'));
  const grossAmount = Number.isFinite(totalAmountRaw) && totalAmountRaw > 0
    ? totalAmountRaw
    : (Number.isFinite(subtotalRaw) ? subtotalRaw : 0);
  if (!grossAmount || grossAmount <= 0) {
    return;
  }

  const configuredTaxRate = Number(invoice.get('taxRate'));
  const taxRatePercent = Number.isFinite(configuredTaxRate) && configuredTaxRate > 0
    ? configuredTaxRate
    : 19.0;
  const vatRate = taxRatePercent / 100.0;

  // Prefer explicit positive taxAmount. Some legacy/client receipts persist
  // `taxAmount = 0` while displaying VAT in line items; in that case derive
  // VAT from gross+rate so AppLedger matches the receipt totals.
  const explicitTaxAmount = Number(invoice.get('taxAmount'));
  let vatAmount = Number.isFinite(explicitTaxAmount) && explicitTaxAmount > 0
    ? explicitTaxAmount
    : NaN;
  if (!Number.isFinite(vatAmount)) {
    if (Number.isFinite(totalAmountRaw) && Number.isFinite(subtotalRaw) && totalAmountRaw > subtotalRaw) {
      vatAmount = totalAmountRaw - subtotalRaw;
    } else {
      const netFromGross = grossAmount / (1 + vatRate);
      vatAmount = grossAmount - netFromGross;
    }
  }

  const netAmount = grossAmount - vatAmount;
  const netRounded = round2(netAmount);
  const vatRounded = round2(vatAmount);
  const clearingDebit = round2(netRounded + vatRounded);

  const investorId = invoice.get('userId') || invoice.get('customerId') || '';
  const investorName = invoice.get('customerName') || '';
  // Prefer explicit `batchId` (iOS + bookAppServiceCharge). Legacy fallbacks:
  // tradeId / orderId / invoice.id.
  const batchId = invoice.get('batchId')
    || invoice.get('tradeId')
    || invoice.get('orderId')
    || invoice.id;
  const invoiceNumberRaw = String(invoice.get('invoiceNumber') || '').trim();

  let referenceDocumentId = '';
  try {
    const refDoc = await ensureServiceChargeInvoiceDocument(invoice);
    if (refDoc && refDoc.id) {
      referenceDocumentId = refDoc.id;
    }
  } catch (err) {
    console.error('ensureServiceChargeInvoiceDocument failed:', err.message);
  }

  const businessReferenceLabel = invoiceNumberRaw
    ? `Rechnung ${invoiceNumberRaw}`
    : `App-Servicegebühr · Batch ${batchId}`;
  const createdAt = invoice.get('createdAt') || new Date();
  const reference = `PSC-${batchId}`;

  const businessCaseId = String(invoice.get('businessCaseId') || '').trim();

  const netPosting = new BankContraPosting();
  netPosting.set('account', 'BANK-PS-NET');
  netPosting.set('side', 'credit');
  netPosting.set('amount', netRounded);
  netPosting.set('investorId', investorId);
  netPosting.set('investorName', investorName);
  netPosting.set('batchId', batchId);
  netPosting.set('investmentIds', invoice.get('investmentIds') || []);
  netPosting.set('reference', reference);
  netPosting.set('metadata', {
    component: 'net',
    grossAmount: grossAmount.toString(),
    invoiceId: invoice.id,
    invoiceNumber: invoice.get('invoiceNumber') || '',
    businessReference: businessReferenceLabel,
    ...(referenceDocumentId ? { referenceDocumentId } : {}),
    ...(invoiceNumberRaw ? { referenceDocumentNumber: invoiceNumberRaw } : {}),
    ...(businessCaseId ? { businessCaseId } : {}),
  });
  netPosting.set('createdAt', createdAt);

  const vatPosting = new BankContraPosting();
  vatPosting.set('account', 'BANK-PS-VAT');
  vatPosting.set('side', 'credit');
  vatPosting.set('amount', vatRounded);
  vatPosting.set('investorId', investorId);
  vatPosting.set('investorName', investorName);
  vatPosting.set('batchId', batchId);
  vatPosting.set('investmentIds', invoice.get('investmentIds') || []);
  vatPosting.set('reference', reference);
  vatPosting.set('metadata', {
    component: 'vat',
    grossAmount: grossAmount.toString(),
    invoiceId: invoice.id,
    invoiceNumber: invoice.get('invoiceNumber') || '',
    businessReference: businessReferenceLabel,
    ...(referenceDocumentId ? { referenceDocumentId } : {}),
    ...(invoiceNumberRaw ? { referenceDocumentNumber: invoiceNumberRaw } : {}),
    ...(businessCaseId ? { businessCaseId } : {}),
  });
  vatPosting.set('createdAt', createdAt);

  await Parse.Object.saveAll([netPosting, vatPosting], { useMasterKey: true });

  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const revEntry = new AppLedgerEntry();
  revEntry.set('account', 'PLT-REV-PSC');
  const revSnapshot = applyLedgerSnapshotToEntry(revEntry, 'PLT-REV-PSC');
  revEntry.set('side', 'credit');
  revEntry.set('amount', netRounded);
  revEntry.set('userId', investorId);
  revEntry.set('userRole', 'investor');
  revEntry.set('transactionType', transactionType);
  revEntry.set('referenceId', batchId);
  revEntry.set('referenceType', 'investment_batch');
  revEntry.set('description', `Appgebühr (netto) – ${investorName || investorId}`);
  revEntry.set('metadata', mergeMetadataWithSnapshot({
    invoiceId: invoice.id,
    invoiceNumber: invoice.get('invoiceNumber') || '',
    ...(referenceDocumentId ? { referenceDocumentId } : {}),
    ...(invoiceNumberRaw
      ? { referenceDocumentNumber: invoiceNumberRaw }
      : {}),
    businessReference: businessReferenceLabel,
    pairedAccounts: 'CLT-LIAB-AVA',
    ...(businessCaseId ? { businessCaseId } : {}),
  }, revSnapshot));
  revEntry.set('createdAt', createdAt);

  const vatEntry = new AppLedgerEntry();
  vatEntry.set('account', 'PLT-TAX-VAT');
  const vatSnapshot = applyLedgerSnapshotToEntry(vatEntry, 'PLT-TAX-VAT');
  vatEntry.set('side', 'credit');
  vatEntry.set('amount', vatRounded);
  vatEntry.set('userId', investorId);
  vatEntry.set('userRole', 'investor');
  vatEntry.set('transactionType', transactionType);
  vatEntry.set('referenceId', batchId);
  vatEntry.set('referenceType', 'investment_batch');
  vatEntry.set('description', `USt. Appgebühr – ${investorName || investorId}`);
  vatEntry.set('metadata', mergeMetadataWithSnapshot({
    invoiceId: invoice.id,
    invoiceNumber: invoice.get('invoiceNumber') || '',
    ...(referenceDocumentId ? { referenceDocumentId } : {}),
    ...(invoiceNumberRaw
      ? { referenceDocumentNumber: invoiceNumberRaw }
      : {}),
    businessReference: businessReferenceLabel,
    pairedAccounts: 'CLT-LIAB-AVA',
    ...(businessCaseId ? { businessCaseId } : {}),
  }, vatSnapshot));
  vatEntry.set('createdAt', createdAt);

  const customerLiabilityEntry = new AppLedgerEntry();
  customerLiabilityEntry.set('account', 'CLT-LIAB-AVA');
  const liabilitySnapshot = applyLedgerSnapshotToEntry(customerLiabilityEntry, 'CLT-LIAB-AVA');
  customerLiabilityEntry.set('side', 'debit');
  customerLiabilityEntry.set('amount', clearingDebit);
  customerLiabilityEntry.set('userId', investorId);
  customerLiabilityEntry.set('userRole', 'investor');
  customerLiabilityEntry.set('transactionType', transactionType);
  customerLiabilityEntry.set('referenceId', batchId);
  customerLiabilityEntry.set('referenceType', 'investment_batch');
  customerLiabilityEntry.set('description', `Belastung Kundenguthaben Appgebühr (brutto) – ${investorName || investorId}`);
  customerLiabilityEntry.set('metadata', mergeMetadataWithSnapshot({
    invoiceId: invoice.id,
    invoiceNumber: invoice.get('invoiceNumber') || '',
    ...(referenceDocumentId ? { referenceDocumentId } : {}),
    ...(invoiceNumberRaw
      ? { referenceDocumentNumber: invoiceNumberRaw }
      : {}),
    businessReference: businessReferenceLabel,
    pairedAccounts: 'PLT-REV-PSC,PLT-TAX-VAT',
    grossAmount: grossAmount.toString(),
    ...(businessCaseId ? { businessCaseId } : {}),
  }, liabilitySnapshot));
  customerLiabilityEntry.set('createdAt', createdAt);

  await Parse.Object.saveAll([revEntry, vatEntry, customerLiabilityEntry], { useMasterKey: true });
}

module.exports = {
  postServiceChargeInvoiceLedger,
};
