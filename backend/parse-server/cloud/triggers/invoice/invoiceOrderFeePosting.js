'use strict';

const { postLedgerPair } = require('../../utils/accountingHelper/journal');

const ORDER_FEE_COMPONENTS = [
  { key: 'orderFee', account: 'PLT-REV-ORD', leg: 'order_fee:orderFee', transactionType: 'orderFee' },
  { key: 'exchangeFee', account: 'PLT-REV-EXC', leg: 'order_fee:exchangeFee', transactionType: 'exchangeFee' },
  { key: 'foreignCosts', account: 'PLT-REV-FRG', leg: 'order_fee:foreignCosts', transactionType: 'foreignCosts' },
];

/**
 * ADR-010 / PR4 — Post AppLedger pairs for an order invoice (one pair per fee component).
 * Idempotency via `journal.postLedgerPair` (referenceId=orderId, transactionType, metadata.leg).
 */
async function postOrderInvoiceFees(invoice) {
  const fees = invoice.get('feeBreakdown') || {};
  if (!fees || typeof fees !== 'object') return;
  const userId = invoice.get('userId') || invoice.get('customerId') || '';
  const userName = invoice.get('customerName') || '';
  const orderId = invoice.get('orderId') || invoice.id;
  const referenceId = orderId;
  const referenceType = 'Order';
  const invNo = String(invoice.get('invoiceNumber') || '').trim();
  const orderBusinessRef = invNo ? `Rechnung ${invNo}` : `Order ${referenceId}`;
  const businessCaseId = String(invoice.get('businessCaseId') || '').trim();

  for (const component of ORDER_FEE_COMPONENTS) {
    const componentAmount = Number(fees[component.key] || 0);
    if (!Number.isFinite(componentAmount) || componentAmount <= 0) continue;
    // eslint-disable-next-line no-await-in-loop
    await postLedgerPair({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: component.account,
      amount: componentAmount,
      userId,
      userRole: 'trader',
      transactionType: component.transactionType,
      referenceId,
      referenceType,
      description: `Handelsgebühr (${component.key}) – ${userName || userId} – Order ${orderId}`,
      metadata: {
        invoiceId: invoice.id,
        invoiceNumber: invoice.get('invoiceNumber') || '',
        ...(invNo ? { referenceDocumentNumber: invNo } : {}),
        orderId: String(orderId || ''),
        businessReference: orderBusinessRef,
        feeComponent: component.key,
        ...(businessCaseId ? { businessCaseId } : {}),
      },
      leg: component.leg,
    });
  }
}

module.exports = {
  postOrderInvoiceFees,
};
