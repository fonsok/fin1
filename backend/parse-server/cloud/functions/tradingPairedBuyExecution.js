'use strict';

const { finalizePairedBuyAfterCommit } = require('../utils/pairedBuyOrchestration');
const { getUserStableId } = require('./tradingIdentity');

/**
 * Atomic paired buy: trader leg + mirror-pool leg, idempotent via clientOrderIntentId.
 */
async function handleExecutePairedBuy(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader role required');
  }

  const {
    symbol,
    price,
    orderInstruction = 'market',
    limitPrice = null,
    optionDirection = null,
    description = null,
    strike = null,
    subscriptionRatio = null,
    denomination = null,
    clientOrderIntentId,
    traderQuantity,
    mirrorPoolQuantity,
  } = request.params || {};

  if (!symbol || typeof symbol !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'symbol required');
  }
  if (!Number.isFinite(price) || Number(price) <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'valid price required');
  }
  if (!['market', 'limit'].includes(String(orderInstruction).toLowerCase())) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'orderInstruction must be market or limit');
  }
  if (String(orderInstruction).toLowerCase() === 'limit' && (!Number.isFinite(limitPrice) || Number(limitPrice) <= 0)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'valid limitPrice required for limit orders');
  }
  if (!Number.isInteger(traderQuantity) || traderQuantity <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'traderQuantity must be an integer > 0');
  }
  if (!Number.isInteger(mirrorPoolQuantity) || mirrorPoolQuantity <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'mirrorPoolQuantity must be an integer > 0');
  }
  if (!clientOrderIntentId || typeof clientOrderIntentId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'clientOrderIntentId required');
  }

  const stableId = getUserStableId(user);
  const intentId = clientOrderIntentId.trim();
  if (!intentId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'clientOrderIntentId must not be empty');
  }

  const PairedExecution = Parse.Object.extend('PairedExecution');
  const existingExecution = await new Parse.Query(PairedExecution)
    .equalTo('traderId', stableId)
    .equalTo('clientOrderIntentId', intentId)
    .first({ useMasterKey: true });

  if (existingExecution) {
    const status = String(existingExecution.get('status') || 'UNKNOWN');
    const pairExecutionId = existingExecution.id;
    if (status === 'COMMITTED' && existingExecution.get('effectsApplied') !== true) {
      try {
        await finalizePairedBuyAfterCommit(pairExecutionId);
      } catch (e) {
        console.error(`executePairedBuy idempotent finalize failed pair=${pairExecutionId}:`, e.message || e);
        throw new Parse.Error(
          Parse.Error.SCRIPT_FAILED,
          `Paired buy finalize failed on retry: ${e && e.message ? e.message : String(e)}`,
        );
      }
    }
    const existingOrders = await new Parse.Query('Order')
      .equalTo('pairExecutionId', pairExecutionId)
      .ascending('createdAt')
      .find({ useMasterKey: true });

    return {
      pairExecutionId,
      idempotentReplay: true,
      status,
      orders: existingOrders.map((o) => ({
        orderId: o.id,
        legType: o.get('legType') || null,
        quantity: o.get('quantity') || 0,
        price: o.get('price') || 0,
        status: o.get('status') || null,
      })),
    };
  }

  const execution = new PairedExecution();
  execution.set('traderId', stableId);
  execution.set('clientOrderIntentId', intentId);
  execution.set('symbol', symbol);
  execution.set('price', Number(price));
  execution.set('status', 'PREPARED');
  execution.set('requestedAt', new Date().toISOString());
  await execution.save(null, { useMasterKey: true });

  const pairExecutionId = execution.id;
  const Order = Parse.Object.extend('Order');

  const createOrderLeg = ({ quantity, legType, isMirrorPoolOrder }) => {
    const order = new Order();
    order.set('traderId', stableId);
    order.set('symbol', symbol);
    order.set('description', description || symbol);
    order.set('type', 'buy');
    order.set('side', 'buy');
    order.set('orderType', String(orderInstruction).toLowerCase());
    order.set('quantity', quantity);
    order.set('price', Number(price));
    order.set('totalAmount', Number(quantity) * Number(price));
    order.set('status', 'submitted');
    order.set('optionDirection', optionDirection);
    order.set('underlyingAsset', description);
    order.set('wkn', symbol);
    order.set('strike', strike);
    order.set('orderInstruction', orderInstruction);
    order.set('limitPrice', limitPrice);
    order.set('subscriptionRatio', subscriptionRatio);
    order.set('denomination', denomination);
    order.set('isMirrorPoolOrder', !!isMirrorPoolOrder);
    order.set('legType', legType);
    order.set('pairExecutionId', pairExecutionId);
    order.set('clientOrderIntentId', intentId);
    return order;
  };

  const traderLeg = createOrderLeg({
    quantity: traderQuantity,
    legType: 'TRADER',
    isMirrorPoolOrder: false,
  });
  const mirrorLeg = createOrderLeg({
    quantity: mirrorPoolQuantity,
    legType: 'MIRROR_POOL',
    isMirrorPoolOrder: true,
  });

  let savedLegs;
  try {
    savedLegs = await Parse.Object.saveAll([traderLeg, mirrorLeg], { useMasterKey: true });
    execution.set('status', 'COMMITTED');
    execution.set('committedAt', new Date().toISOString());
    execution.set('orderIds', savedLegs.map((o) => o.id));
    await execution.save(null, { useMasterKey: true });
  } catch (error) {
    const partialOrders = await new Parse.Query('Order')
      .equalTo('pairExecutionId', pairExecutionId)
      .find({ useMasterKey: true });

    if (partialOrders.length > 0) {
      try {
        await Parse.Object.destroyAll(partialOrders, { useMasterKey: true });
      } catch (destroyError) {
        console.error(`executePairedBuy: failed to compensate partial orders for pair ${pairExecutionId}:`, destroyError.message);
      }
    }

    execution.set('status', 'ABORTED');
    execution.set('abortedAt', new Date().toISOString());
    execution.set('failureReason', error && error.message ? error.message : 'Unknown error');
    await execution.save(null, { useMasterKey: true });

    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      `Paired execution aborted: ${error && error.message ? error.message : 'Unknown error'}`,
    );
  }

  try {
    await finalizePairedBuyAfterCommit(pairExecutionId);
  } catch (finalizeErr) {
    console.error(`executePairedBuy finalize failed pair=${pairExecutionId}:`, finalizeErr.message || finalizeErr);
    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      `Paired buy orders saved but server settlement failed: ${finalizeErr && finalizeErr.message ? finalizeErr.message : String(finalizeErr)}`,
    );
  }

  return {
    pairExecutionId,
    idempotentReplay: false,
    status: 'COMMITTED',
    orders: savedLegs.map((o) => ({
      orderId: o.id,
      legType: o.get('legType') || null,
      quantity: o.get('quantity') || 0,
      price: o.get('price') || 0,
      status: o.get('status') || null,
    })),
  };
}

module.exports = {
  handleExecutePairedBuy,
};
