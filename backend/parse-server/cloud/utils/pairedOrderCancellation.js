'use strict';

const {
  CANCELLABLE_STATUSES,
  normalizeStatus,
  isCancellableStatus,
  pairedStatusBatchContext,
} = require('./pairedOrderShared');

function assertNoExecutionArtifacts(order) {
  const status = normalizeStatus(order.get('status'));
  if (!isCancellableStatus(status)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Order cannot be cancelled in status "${status}"`,
    );
  }
  const tradeId = String(order.get('tradeId') || '').trim();
  if (tradeId) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Order already linked to a trade — cancellation not allowed',
    );
  }
  const executedQty = Number(order.get('executedQuantity') || 0);
  if (executedQty > 0) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Order already partially or fully executed — cancellation not allowed',
    );
  }
}

/**
 * Loads the order plus all paired legs (same pairExecutionId) when present.
 * @returns {Promise<{ anchor: Parse.Object, orders: Parse.Object[], pairExecutionId: string|null }>}
 */
async function loadOrdersForCancellation(orderId, traderId) {
  const anchor = await new Parse.Query('Order').get(orderId, { useMasterKey: true });
  const ownerId = String(anchor.get('traderId') || '').trim();
  if (ownerId !== String(traderId || '').trim()) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Order does not belong to this trader');
  }

  const pairExecutionId = String(anchor.get('pairExecutionId') || '').trim() || null;
  if (!pairExecutionId) {
    return { anchor, orders: [anchor], pairExecutionId: null };
  }

  const legs = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairExecutionId)
    .equalTo('traderId', traderId)
    .find({ useMasterKey: true });

  if (!legs.length) {
    return { anchor, orders: [anchor], pairExecutionId };
  }

  return { anchor, orders: legs, pairExecutionId };
}

/**
 * Cancels a trader order. When the order belongs to a paired buy (pairExecutionId),
 * all legs (TRADER + MIRROR_POOL) are cancelled together — only while pre-execution.
 *
 * @param {string} orderId — any leg or standalone order id
 * @param {string} traderId — stable trader id
 */
async function cancelTraderOrder(orderId, traderId) {
  const { orders, pairExecutionId } = await loadOrdersForCancellation(orderId, traderId);

  for (const order of orders) {
    assertNoExecutionArtifacts(order);
  }

  const now = new Date();
  const cancelledIds = [];

  for (const order of orders) {
    order.set('status', 'cancelled');
    order.set('cancelledAt', now);
    order.set('remainingQuantity', 0);
    cancelledIds.push(order.id);
  }

  if (orders.length > 0) {
    await Parse.Object.saveAll(orders, {
      useMasterKey: true,
      context: pairedStatusBatchContext(),
    });
  }

  if (pairExecutionId) {
    const PairedExecution = Parse.Object.extend('PairedExecution');
    try {
      const execution = await new Parse.Query(PairedExecution).get(pairExecutionId, { useMasterKey: true });
      if (execution.get('effectsApplied') === true) {
        throw new Parse.Error(
          Parse.Error.OPERATION_FORBIDDEN,
          'Paired execution already settled — cancellation not allowed',
        );
      }
      execution.set('status', 'CANCELLED');
      execution.set('cancelledAt', now.toISOString());
      await execution.save(null, { useMasterKey: true });
    } catch (err) {
      if (err instanceof Parse.Error) throw err;
      console.warn(`cancelTraderOrder: PairedExecution ${pairExecutionId} not updated:`, err.message || err);
    }
  }

  return {
    orderId,
    pairExecutionId,
    cancelledOrderIds: cancelledIds,
    cancelledLegCount: cancelledIds.length,
  };
}

module.exports = {
  CANCELLABLE_STATUSES,
  isCancellableStatus,
  cancelTraderOrder,
  loadOrdersForCancellation,
};
