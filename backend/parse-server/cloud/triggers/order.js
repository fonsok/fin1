// ============================================================================
// Parse Cloud Code
// triggers/order.js - Order Triggers
// ============================================================================

'use strict';

const { generateSequentialNumber, calculateOrderFees } = require('../utils/helpers');

// ============================================================================
// BEFORE SAVE
// ============================================================================

Parse.Cloud.beforeSave('Order', async (request) => {
  const order = request.object;
  const isNew = !order.existed();

  if (isNew) {
    // Generate order number
    if (!order.get('orderNumber')) {
      const orderNumber = await generateSequentialNumber('ORD', 'Order', 'orderNumber');
      order.set('orderNumber', orderNumber);
    }

    // Validate required fields
    const requiredFields = ['traderId', 'symbol', 'side', 'orderType', 'quantity'];
    for (const field of requiredFields) {
      if (!order.get(field)) {
        throw new Parse.Error(Parse.Error.INVALID_VALUE, `${field} is required`);
      }
    }

    // Validate side
    const side = order.get('side');
    if (!['buy', 'sell'].includes(side)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Side must be buy or sell');
    }

    // Validate order type
    const orderType = order.get('orderType');
    if (!['market', 'limit', 'stop', 'stop_limit'].includes(orderType)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid order type');
    }

    // Limit price required for limit orders
    if (['limit', 'stop_limit'].includes(orderType) && !order.get('limitPrice')) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Limit price required for limit orders');
    }

    // Stop price required for stop orders
    if (['stop', 'stop_limit'].includes(orderType) && !order.get('stopPrice')) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Stop price required for stop orders');
    }

    // Set defaults
    order.set('status', 'pending');
    order.set('executedQuantity', 0);
    order.set('remainingQuantity', order.get('quantity'));
    order.set('timeInForce', order.get('timeInForce') || 'day');
  }

  // Update remaining quantity
  const quantity = order.get('quantity') || 0;
  const executedQuantity = order.get('executedQuantity') || 0;
  order.set('remainingQuantity', quantity - executedQuantity);
});

// ============================================================================
// AFTER SAVE
// ============================================================================

Parse.Cloud.afterSave('Order', async (request) => {
  const order = request.object;
  const isNew = !request.original;

  // Status change handling
  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = order.get('status');

    if (oldStatus !== newStatus) {
      // Order executed
      if (newStatus === 'executed') {
        order.set('executedAt', new Date());

        const side = order.get('side');
        const traderId = order.get('traderId');

        if (side === 'buy') {
          // Create or update trade
          await handleBuyOrderExecuted(order);
        } else {
          // Update existing trade
          await handleSellOrderExecuted(order);
        }

        // Create invoice
        await createOrderInvoice(order);

        // Notify trader
        await createNotification(traderId, 'order_executed', 'trading',
          'Order ausgeführt',
          `Ihre ${side === 'buy' ? 'Kauf' : 'Verkauf'}order für ${order.get('symbol')} ` +
          `wurde zu ${formatCurrency(order.get('price'))} ausgeführt.`);
      }

      // Order cancelled
      if (newStatus === 'cancelled') {
        order.set('cancelledAt', new Date());

        await createNotification(order.get('traderId'), 'order_cancelled', 'trading',
          'Order storniert',
          `Ihre Order für ${order.get('symbol')} wurde storniert.`);
      }
    }
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

async function handleBuyOrderExecuted(order) {
  const Trade = Parse.Object.extend('Trade');
  const trade = new Trade();

  trade.set('traderId', order.get('traderId'));
  trade.set('buyOrderId', order.id);
  trade.set('symbol', order.get('symbol'));
  trade.set('securityName', order.get('securityName'));
  trade.set('securityType', order.get('securityType'));
  trade.set('wkn', order.get('wkn'));
  trade.set('quantity', order.get('executedQuantity'));
  trade.set('buyPrice', order.get('price'));
  trade.set('buyAmount', order.get('grossAmount'));
  trade.set('status', 'active');
  trade.set('openedAt', new Date());

  const savedTrade = await trade.save(null, { useMasterKey: true });

  // Link order to trade
  order.set('tradeId', savedTrade.id);
  await order.save(null, { useMasterKey: true });

  // Allocate from investment pools
  await allocateTradeToInvestmentPools(savedTrade);
}

async function handleSellOrderExecuted(order) {
  const tradeId = order.get('tradeId');
  if (!tradeId) return;

  const Trade = Parse.Object.extend('Trade');
  const trade = await new Parse.Query(Trade).get(tradeId, { useMasterKey: true });

  if (!trade) return;

  const sellQuantity = order.get('executedQuantity');
  const sellPrice = order.get('price');
  const sellAmount = order.get('grossAmount');

  // Update trade
  const newSoldQuantity = (trade.get('soldQuantity') || 0) + sellQuantity;
  trade.set('soldQuantity', newSoldQuantity);

  // Calculate profit for this sell
  const buyPrice = trade.get('buyPrice');
  const profitPerUnit = sellPrice - buyPrice;
  const grossProfit = profitPerUnit * sellQuantity;

  const totalSellAmount = (trade.get('sellAmount') || 0) + sellAmount;
  const totalGrossProfit = (trade.get('grossProfit') || 0) + grossProfit;

  trade.set('sellAmount', totalSellAmount);
  trade.set('grossProfit', totalGrossProfit);
  trade.set('averageSellPrice', totalSellAmount / newSoldQuantity);

  // Calculate profit percentage
  const buyAmount = trade.get('buyAmount');
  if (buyAmount > 0) {
    trade.set('profitPercentage', (totalGrossProfit / buyAmount) * 100);
  }

  await trade.save(null, { useMasterKey: true });
}

async function allocateTradeToInvestmentPools(trade) {
  const traderId = trade.get('traderId');
  const tradeAmount = trade.get('buyAmount');

  // Find active investments for this trader
  const Investment = Parse.Object.extend('Investment');
  const query = new Parse.Query(Investment);
  query.equalTo('traderId', traderId);
  query.containedIn('status', ['active', 'executing']);

  const investments = await query.find({ useMasterKey: true });

  if (investments.length === 0) return;

  // Calculate total pool
  let totalPool = 0;
  for (const inv of investments) {
    totalPool += inv.get('currentValue') || 0;
  }

  if (totalPool === 0) return;

  // Allocate proportionally
  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');

  for (const investment of investments) {
    const invValue = investment.get('currentValue') || 0;
    const ownershipPct = (invValue / totalPool) * 100;
    const allocatedAmount = tradeAmount * (ownershipPct / 100);

    const participation = new PoolParticipation();
    participation.set('investmentId', investment.id);
    participation.set('tradeId', trade.id);
    participation.set('allocatedAmount', allocatedAmount);
    participation.set('ownershipPercentage', ownershipPct);
    participation.set('isSettled', false);

    await participation.save(null, { useMasterKey: true });
  }
}

async function createOrderInvoice(order) {
  const Invoice = Parse.Object.extend('Invoice');
  const invoice = new Invoice();

  const side = order.get('side');
  const isSell = side === 'sell';
  const invoiceType = isSell ? 'sell_invoice' : 'buy_invoice';
  const grossAmount = order.get('grossAmount') || 0;
  const quantity = order.get('executedQuantity') || order.get('quantity') || 0;
  const price = order.get('price') || 0;

  // Generate invoice number
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

  // Calculate fee breakdown using the same logic as the frontend
  const fees = calculateOrderFees(grossAmount, false);
  const sign = isSell ? -1 : 1;

  // Build structured line items matching the frontend InvoiceFactory format
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
    { description: 'Ordergebühr',                 quantity: 1, unitPrice: sign * fees.orderFee,    itemType: 'orderFee' },
    { description: 'Börsenplatzgebühr (XETRA)',    quantity: 1, unitPrice: sign * fees.exchangeFee, itemType: 'exchangeFee' },
    { description: 'Fremdkostenpauschale',         quantity: 1, unitPrice: sign * fees.foreignCosts, itemType: 'foreignCosts' },
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

  await invoice.save(null, { useMasterKey: true });
  console.log(`📄 Invoice ${invoiceNumber} created for ${side} order ${order.id}, fees=€${fees.totalFees}`);
}

async function createNotification(userId, type, category, title, message) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}
