'use strict';

const { generateSequentialNumber } = require('../../helpers');
const { round2, formatDateCompact, generateShortHash } = require('../shared');
const { applyBusinessCaseIdToDocument } = require('./shared');

/**
 * GoB-compliant receipt for wallet transactions (Keine Buchung ohne Beleg)
 * Covers: deposit, withdrawal, investment_activate, investment_return, refund
 */
async function createWalletReceiptDocument({
  userId,
  receiptType,
  amount,
  description,
  referenceType,
  referenceId,
  metadata: extraMeta,
  businessCaseId,
}) {
  const typeToDocType = {
    deposit: 'financial',
    withdrawal: 'financial',
    investment: 'financial',
    investment_return: 'financial',
    refund: 'financial',
  };

  const typeToPrefix = {
    deposit: 'WDR',
    withdrawal: 'WWR',
    investment: 'IAR',
    investment_return: 'IRR',
    refund: 'IFR',
  };

  const docType = typeToDocType[receiptType] || `wallet_${receiptType}_receipt`;
  const prefix = typeToPrefix[receiptType] || 'WRC';

  const docNumber = await generateSequentialNumber(prefix, 'Document', 'accountingDocumentNumber');
  const dateStr = formatDateCompact(new Date());
  const hash = generateShortHash();

  const Document = Parse.Object.extend('Document');
  const doc = new Document();
  doc.set('userId', userId);
  doc.set('type', docType);
  doc.set('name', `${docType}_${dateStr}_${hash}.pdf`);
  doc.set('accountingDocumentNumber', docNumber);
  doc.set('source', 'backend');
  if (referenceType) doc.set('referenceType', referenceType);
  if (referenceId) doc.set('referenceId', referenceId);
  if (referenceType === 'Investment' && referenceId) {
    doc.set('investmentId', referenceId);
  }
  doc.set('metadata', {
    amount: round2(Math.abs(amount)),
    description,
    receiptType,
    ...extraMeta,
    generatedAt: new Date().toISOString(),
  });

  applyBusinessCaseIdToDocument(doc, businessCaseId);

  await doc.save(null, { useMasterKey: true });
  console.log(`📄 WalletReceipt created: ${docNumber} (${docType}) for user ${userId}, €${round2(Math.abs(amount))}`);
  return doc;
}

module.exports = {
  createWalletReceiptDocument,
};
