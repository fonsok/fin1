'use strict';

const { round2 } = require('../accountingHelper/shared');

function passthroughStatementTitle(entryType) {
  if (entryType === 'commission_credit') return 'Gutschrift Provision';
  if (entryType === 'deposit') return 'Einzahlung';
  if (entryType === 'withdrawal') return 'Auszahlung';
  return null;
}

function buildDisplayEventFromStatementEntry(entry) {
  const entryType = String(entry.get('entryType') || '');
  return {
    objectId: entry.id,
    entryType,
    amount: round2(Number(entry.get('amount') || 0)),
    at: entry.get('createdAt') || new Date(),
    tradeId: entry.get('tradeId') || null,
    tradeNumber: entry.get('tradeNumber') ?? null,
    referenceDocumentId: entry.get('referenceDocumentId') || null,
    referenceDocumentNumber: entry.get('referenceDocumentNumber') || null,
    description: entry.get('description') || entryType,
    source: 'customer_display',
    statementTitle: passthroughStatementTitle(entryType),
    transactionTypeLabel: null,
    wknOrIsin: null,
    underlyingAsset: null,
    securitiesDirection: null,
    quantity: null,
    strikePrice: null,
    issuer: null,
    displayAmountMode: null,
    netAmount: Math.abs(Number(entry.get('amount') || 0)),
  };
}

module.exports = {
  passthroughStatementTitle,
  buildDisplayEventFromStatementEntry,
};
