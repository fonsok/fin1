'use strict';

const { generateSequentialNumber } = require('../utils/helpers');

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

    order.set('status', 'pending');
    order.set('executedQuantity', 0);
    order.set('remainingQuantity', order.get('quantity'));
    order.set('timeInForce', order.get('timeInForce') || 'day');
  }

  const quantity = order.get('quantity') || 0;
  const executedQuantity = order.get('executedQuantity') || 0;
  order.set('remainingQuantity', quantity - executedQuantity);
});
