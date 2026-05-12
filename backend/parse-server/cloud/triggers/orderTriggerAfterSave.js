'use strict';

const { handleBuyOrderExecuted, handleSellOrderExecuted } = require('./orderBuySellHandlers');
const { createOrderInvoice } = require('./orderInvoice');
const { formatCurrency, createOrderNotification } = require('./orderNotifications');

Parse.Cloud.afterSave('Order', async (request) => {
  const order = request.object;

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = order.get('status');

    if (oldStatus !== newStatus) {
      if (newStatus === 'executed') {
        order.set('executedAt', new Date());

        const side = order.get('side');
        const traderId = order.get('traderId');

        if (side === 'buy') {
          await handleBuyOrderExecuted(order);
        } else {
          await handleSellOrderExecuted(order);
        }

        await createOrderInvoice(order);

        await createOrderNotification(traderId, 'order_executed', 'trading',
          'Order ausgeführt',
          `Ihre ${side === 'buy' ? 'Kauf' : 'Verkauf'}order für ${order.get('symbol')} ` +
          `wurde zu ${formatCurrency(order.get('price'))} ausgeführt.`);
      }

      if (newStatus === 'cancelled') {
        order.set('cancelledAt', new Date());

        await createOrderNotification(order.get('traderId'), 'order_cancelled', 'trading',
          'Order storniert',
          `Ihre Order für ${order.get('symbol')} wurde storniert.`);
      }
    }
  }
});
