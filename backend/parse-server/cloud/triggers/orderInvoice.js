'use strict';

const { calculateOrderFees } = require('../utils/helpers');
const { ensureBusinessCaseIdForTrade, newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');

async function createOrderInvoice(order) {
  const Invoice = Parse.Object.extend('Invoice');
  const invoice = new Invoice();

  const side = order.get('side');
  const isSell = side === 'sell';
  const invoiceType = isSell ? 'sell_invoice' : 'buy_invoice';
  const grossAmount = order.get('grossAmount') || 0;
  const quantity = order.get('executedQuantity') || order.get('quantity') || 0;
  const price = order.get('price') || 0;

  const docPrefix = process.env.FIN1_LEGAL_DOCUMENT_PREFIX || '';
  const invPrefix = docPrefix ? `${docPrefix}-INV` : 'INV';
  const year = new Date().getFullYear();
  const pattern = `${invPrefix}-${year}-`;
  const lastInvoice = await new Parse.Query('Invoice')
    .startsWith('invoiceNumber', pattern)
    .descending('invoiceNumber')
    .first({ useMasterKey: true });

  let seq = 1;
  if (lastInvoice) {
    const num = lastInvoice.get('invoiceNumber');
    const parts = num.split('-');
    const seqPart = docPrefix ? parts[3] : parts[2];
    seq = parseInt(seqPart, 10) + 1;
  }

  const invoiceNumber = `${invPrefix}-${year}-${seq.toString().padStart(7, '0')}`;

  const fees = calculateOrderFees(grossAmount, false);
  const sign = isSell ? -1 : 1;

  const lineItems = [
    {
      description: [
        order.get('wkn') || '',
        order.get('optionDirection') || '',
        order.get('symbol') || '',
        order.get('strike') ? `Strike ${order.get('strike')}` : '',
      ].filter(Boolean).join(' - '),
      quantity,
      unitPrice: price,
      itemType: 'securities',
    },
    { description: 'Ordergebühr', quantity: 1, unitPrice: sign * fees.orderFee, itemType: 'orderFee' },
    { description: 'Börsenplatzgebühr (XETRA)', quantity: 1, unitPrice: sign * fees.exchangeFee, itemType: 'exchangeFee' },
    { description: 'Fremdkostenpauschale', quantity: 1, unitPrice: sign * fees.foreignCosts, itemType: 'foreignCosts' },
  ];

  invoice.set('invoiceNumber', invoiceNumber);
  invoice.set('invoiceType', invoiceType);
  invoice.set('userId', order.get('traderId'));
  invoice.set('orderId', order.id);
  invoice.set('tradeId', order.get('tradeId'));
  invoice.set('symbol', order.get('symbol'));
  invoice.set('side', side);
  invoice.set('quantity', quantity);
  invoice.set('price', price);
  invoice.set('subtotal', grossAmount);
  invoice.set('totalFees', fees.totalFees);
  invoice.set('totalAmount', order.get('netAmount') || grossAmount);
  invoice.set('feeBreakdown', {
    orderFee: fees.orderFee,
    exchangeFee: fees.exchangeFee,
    foreignCosts: fees.foreignCosts,
    totalFees: fees.totalFees,
  });
  invoice.set('lineItems', lineItems);
  invoice.set('invoiceDate', new Date());
  invoice.set('status', 'issued');
  invoice.set('source', 'backend');

  let businessCaseId = '';
  const linkedTradeId = order.get('tradeId');
  if (linkedTradeId) {
    try {
      const tr = await new Parse.Query('Trade').get(linkedTradeId, { useMasterKey: true });
      businessCaseId = await ensureBusinessCaseIdForTrade(tr);
    } catch (_) { /* order may lack trade yet */ }
  }
  if (!businessCaseId) {
    businessCaseId = newBusinessCaseId();
  }
  invoice.set('businessCaseId', businessCaseId);

  await invoice.save(null, { useMasterKey: true });
  console.log(`📄 Invoice ${invoiceNumber} created for ${side} order ${order.id}, fees=€${fees.totalFees}`);
}

module.exports = {
  createOrderInvoice,
};
