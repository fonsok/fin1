'use strict';

const { SETTLEMENT_INVOICE_TYPES } = require('./shared');

function isSettlementTradeInvoice(invoice) {
  const type = String(invoice.get('invoiceType') || '').toLowerCase();
  return SETTLEMENT_INVOICE_TYPES.has(type);
}

function invoiceTransactionType(invoice) {
  const type = String(invoice.get('invoiceType') || '').toLowerCase();
  const side = String(invoice.get('side') || '').toLowerCase();
  if (type.includes('sell') || side === 'sell') return 'sell';
  if (type.includes('buy') || side === 'buy') return 'buy';
  return null;
}

function invoiceOccurredAt(invoice) {
  return invoice.get('invoiceDate') || invoice.get('createdAt') || new Date();
}

module.exports = {
  isSettlementTradeInvoice,
  invoiceTransactionType,
  invoiceOccurredAt,
};
