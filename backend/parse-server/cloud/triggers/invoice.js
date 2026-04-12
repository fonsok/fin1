'use strict';

// ============================================================================
// Parse Cloud Code
// triggers/invoice.js - Invoice Triggers (Bank Contra for Service Charges)
// ============================================================================

const { round2 } = require('../utils/accountingHelper/shared');

/**
 * After saving an Invoice, create BankContraPosting entries for
 * platform service charge invoices so that the Bank Contra Ledger
 * (BANK-PS-NET / BANK-PS-VAT) is always populated from backend data.
 *
 * App-Hauptbuch (AppLedgerEntry): vollständiger Satz für App-Servicegebühr
 *   S PLT-CLR-GEN   brutto (Einzahlung / Gegenkonto zur Wallet-Abführung)
 *   H PLT-REV-PSC   netto
 *   H PLT-TAX-VAT   USt-Anteil
 */
Parse.Cloud.afterSave('Invoice', async (request) => {
  const invoice = request.object;
  const isNew = !request.original;

  // Only act on new invoices or when invoiceType changed
  if (!isNew) {
    const oldType = request.original.get('invoiceType');
    const newType = invoice.get('invoiceType');
    if (oldType === newType) {
      return;
    }
  }

  const invoiceType = invoice.get('invoiceType') || '';

  // Only handle platform service charge invoices
  if (invoiceType !== 'service_charge' && invoiceType !== 'platform_service_charge') {
    return;
  }

  try {
    const BankContraPosting = Parse.Object.extend('BankContraPosting');

    const grossAmount = invoice.get('totalAmount') || invoice.get('subtotal') || 0;
    if (!grossAmount || grossAmount <= 0) {
      return;
    }

    // Prefer explicit taxAmount if available, otherwise derive from gross using 19% VAT
    let vatAmount = invoice.get('taxAmount');
    if (typeof vatAmount !== 'number') {
      const vatRate = (invoice.get('taxRate') || 19.0) / 100.0;
      const netFromGross = grossAmount / (1 + vatRate);
      vatAmount = grossAmount - netFromGross;
    }

    const netAmount = grossAmount - vatAmount;
    const netRounded = round2(netAmount);
    const vatRounded = round2(vatAmount);
    const clearingDebit = round2(netRounded + vatRounded);

    const investorId = invoice.get('userId') || '';
    const investorName = invoice.get('customerName') || '';
    const batchId = invoice.get('tradeId') || invoice.get('orderId') || invoice.id;
    const createdAt = invoice.get('createdAt') || new Date();
    const reference = `PSC-${batchId}`;

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
    });
    vatPosting.set('createdAt', createdAt);

    await Parse.Object.saveAll([netPosting, vatPosting], { useMasterKey: true });

    // Doppelte Buchführung (AppLedger): S Verrechnung = H Erlös + H USt
    const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
    const revEntry = new AppLedgerEntry();
    revEntry.set('account', 'PLT-REV-PSC');
    revEntry.set('side', 'credit');
    revEntry.set('amount', netRounded);
    revEntry.set('userId', investorId);
    revEntry.set('userRole', 'investor');
    revEntry.set('transactionType', 'platformServiceCharge');
    revEntry.set('referenceId', batchId);
    revEntry.set('referenceType', 'investment_batch');
    revEntry.set('description', `Appgebühr (netto) – ${investorName || investorId}`);
    revEntry.set('metadata', { invoiceId: invoice.id, invoiceNumber: invoice.get('invoiceNumber') || '' });
    revEntry.set('createdAt', createdAt);

    const vatEntry = new AppLedgerEntry();
    vatEntry.set('account', 'PLT-TAX-VAT');
    vatEntry.set('side', 'credit');
    vatEntry.set('amount', vatRounded);
    vatEntry.set('userId', investorId);
    vatEntry.set('userRole', 'investor');
    vatEntry.set('transactionType', 'platformServiceCharge');
    vatEntry.set('referenceId', batchId);
    vatEntry.set('referenceType', 'investment_batch');
    vatEntry.set('description', `USt. Appgebühr – ${investorName || investorId}`);
    vatEntry.set('metadata', { invoiceId: invoice.id, invoiceNumber: invoice.get('invoiceNumber') || '' });
    vatEntry.set('createdAt', createdAt);

    const clearingEntry = new AppLedgerEntry();
    clearingEntry.set('account', 'PLT-CLR-GEN');
    clearingEntry.set('side', 'debit');
    clearingEntry.set('amount', clearingDebit);
    clearingEntry.set('userId', investorId);
    clearingEntry.set('userRole', 'investor');
    clearingEntry.set('transactionType', 'platformServiceCharge');
    clearingEntry.set('referenceId', batchId);
    clearingEntry.set('referenceType', 'investment_batch');
    clearingEntry.set('description', `Verrechnung Appgebühr brutto (Gegenbuch zu Wallet) – ${investorName || investorId}`);
    clearingEntry.set('metadata', {
      invoiceId: invoice.id,
      invoiceNumber: invoice.get('invoiceNumber') || '',
      pairedAccounts: 'PLT-REV-PSC,PLT-TAX-VAT',
      grossAmount: grossAmount.toString(),
    });
    clearingEntry.set('createdAt', createdAt);

    await Parse.Object.saveAll([revEntry, vatEntry, clearingEntry], { useMasterKey: true });
  } catch (err) {
    // Non-fatal: ledger/contra reporting should never block invoice creation
    console.error('afterSave Invoice: failed to create BankContraPosting/AppLedgerEntry:', err.message);
  }
});

