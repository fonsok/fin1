'use strict';

const { calculateOrderFees } = require('../utils/helpers');
const { ensureBusinessCaseIdForTrade, newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');

async function createOrderInvoice(order) {
  const side = order.get('side');
  const isSell = side === 'sell';
  const invoiceType = isSell ? 'sell_invoice' : 'buy_invoice';

  const invoiceTypes = ['buy_invoice', 'sell_invoice', 'buy', 'sell'];
  const existingByOrder = await new Parse.Query('Invoice')
    .equalTo('orderId', order.id)
    .containedIn('invoiceType', invoiceTypes)
    .first({ useMasterKey: true });
  if (existingByOrder) {
    console.log(`📄 Invoice already exists for order ${order.id}: ${existingByOrder.get('invoiceNumber')}`);
    return existingByOrder;
  }

  const linkedTradeId = String(order.get('tradeId') || '').trim();
  // One buy invoice per trade; each partial sell has its own sell order + invoice.
  if (linkedTradeId && !isSell) {
    const existingByTrade = await new Parse.Query('Invoice')
      .equalTo('tradeId', linkedTradeId)
      .equalTo('invoiceType', invoiceType)
      .first({ useMasterKey: true });
    if (existingByTrade) {
      console.log(`📄 Invoice already exists for trade ${linkedTradeId}: ${existingByTrade.get('invoiceNumber')}`);
      return existingByTrade;
    }
  }

  const Invoice = Parse.Object.extend('Invoice');
  const invoice = new Invoice();
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

  const wkn = String(order.get('wkn') || '').trim();
  const optionDirection = String(order.get('optionDirection') || '').trim();
  const underlyingAsset = String(order.get('underlyingAsset') || '').trim();
  const symbol = String(order.get('symbol') || '').trim();
  const strike = order.get('strikePrice') ?? order.get('strike');
  const strikeText = strike != null && String(strike).trim()
    ? `Strike ${strike}`
    : '';
  const issuer = String(order.get('issuer') || '').trim();

  const lineItems = [
    {
      description: [
        wkn,
        optionDirection,
        underlyingAsset || symbol,
        strikeText,
      ].filter(Boolean).join(' - '),
      quantity,
      unitPrice: price,
      itemType: 'securities',
      wkn,
      optionDirection,
      underlyingAsset,
      symbol,
      strikePrice: strike != null ? String(strike) : '',
      issuer,
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
