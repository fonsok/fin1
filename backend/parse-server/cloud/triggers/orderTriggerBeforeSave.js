'use strict';

const { generateSequentialNumber } = require('../utils/helpers');
const { assertPairedOrderStatusCouplingOnSave } = require('../utils/pairedOrderStatusCoupling');
const {
  resolveOrderExecutionPrice,
  applyExecutionPriceMetaToOrder,
} = require('../utils/executionPriceResolver');

Parse.Cloud.beforeSave('Order', async (request) => {
  const order = request.object;
  const isNew = !order.existed();

  if (isNew) {
    if (!order.get('orderNumber')) {
      const orderNumber = await generateSequentialNumber('ORD', 'Order', 'orderNumber');
      order.set('orderNumber', orderNumber);
    }

    const requiredFields = ['traderId', 'symbol', 'side', 'orderType', 'quantity'];
    for (const field of requiredFields) {
      if (!order.get(field)) {
        throw new Parse.Error(Parse.Error.INVALID_VALUE, `${field} is required`);
      }
    }

    const side = order.get('side');
    if (!['buy', 'sell'].includes(side)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Side must be buy or sell');
    }

    const orderType = order.get('orderType');
    if (!['market', 'limit', 'stop', 'stop_limit'].includes(orderType)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid order type');
    }

    if (['limit', 'stop_limit'].includes(orderType) && !order.get('limitPrice')) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Limit price required for limit orders');
    }

    if (['stop', 'stop_limit'].includes(orderType) && !order.get('stopPrice')) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Stop price required for stop orders');
    }

    if (!order.get('status')) {
      order.set('status', 'pending');
    }
    order.set('executedQuantity', 0);
    order.set('remainingQuantity', order.get('quantity'));
    order.set('timeInForce', order.get('timeInForce') || 'day');

    if (
      side === 'buy'
      && !order.get('executionPriceSource')
      && !order.get('pairExecutionId')
    ) {
      const clientPrice = Number(order.get('price') || order.get('limitPrice') || 0);
      const priceMeta = await resolveOrderExecutionPrice({
        symbol: order.get('symbol'),
        orderType: order.get('orderType'),
        limitPrice: order.get('limitPrice'),
        clientPrice,
        clientQuotedAt: order.get('clientQuotedAt'),
      });
      applyExecutionPriceMetaToOrder(order, priceMeta);
    }
  }

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = order.get('status');
    if (oldStatus !== newStatus && newStatus === 'cancelled') {
      const cancellable = ['pending', 'submitted', 'suspended'];
      if (!cancellable.includes(String(oldStatus || '').toLowerCase())) {
        throw new Parse.Error(
          Parse.Error.OPERATION_FORBIDDEN,
          `Order cannot be cancelled from status "${oldStatus}"`,
        );
      }
      if (String(order.get('tradeId') || '').trim()) {
        throw new Parse.Error(
          Parse.Error.OPERATION_FORBIDDEN,
          'Order linked to trade — use cancelOrder cloud function for paired legs',
        );
      }
    }
    if (oldStatus !== newStatus && newStatus === 'executed') {
      const qty = Number(order.get('quantity') || 0);
      const executedQty = Number(order.get('executedQuantity') || 0);
      if (qty > 0 && executedQty <= 0) {
        order.set('executedQuantity', qty);
      }
      if (!order.get('executedAt')) {
        order.set('executedAt', new Date());
      }
      const price = Number(order.get('price') || order.get('limitPrice') || 0);
      const grossAmount = Number(order.get('grossAmount') || 0);
      if (grossAmount <= 0 && qty > 0 && price > 0) {
        order.set('grossAmount', qty * price);
      }
    }
  }

  await assertPairedOrderStatusCouplingOnSave(order, request);

  const quantity = order.get('quantity') || 0;
  const executedQuantity = order.get('executedQuantity') || 0;
  order.set('remainingQuantity', quantity - executedQuantity);
});
