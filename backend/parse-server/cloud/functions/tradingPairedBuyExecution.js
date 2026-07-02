'use strict';

const { getUserStableId } = require('./tradingIdentity');
const { capMirrorPoolQuantityForBuy } = require('../utils/poolMirrorBuyCap');
const { resolvePairedBuyExecutionPrice } = require('../utils/executionPriceResolver');
const { getMinTraderBuyOrderAmount, assertTraderBuyOrderMeetsMinimum } = require('../utils/configHelper/minTraderBuyOrderAmount');
const { assertTraderCanOpenNewDepotPosition } = require('../utils/configHelper/traderOpenDepotLimits');

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
  if (!['market', 'limit'].includes(String(orderInstruction).toLowerCase())) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'orderInstruction must be market or limit');
  }
  if (!Number.isInteger(traderQuantity) || traderQuantity <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'traderQuantity must be an integer > 0');
  }
  if (!Number.isInteger(mirrorPoolQuantity) || mirrorPoolQuantity < 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'mirrorPoolQuantity must be a non-negative integer');
  }
  if (!clientOrderIntentId || typeof clientOrderIntentId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'clientOrderIntentId required');
  }

  const priceResolution = await resolvePairedBuyExecutionPrice({
    symbol,
    orderInstruction,
    limitPrice,
  });
  const executionPrice = priceResolution.executionPrice;

  const stableId = getUserStableId(user);
  let effectiveMirrorPoolQuantity = mirrorPoolQuantity;

  if (effectiveMirrorPoolQuantity > 0) {
    const capResult = await capMirrorPoolQuantityForBuy({
      mirrorPoolQuantity: effectiveMirrorPoolQuantity,
      price: executionPrice,
      traderId: stableId,
    });
    effectiveMirrorPoolQuantity = capResult.mirrorPoolQuantity;
    if (capResult.capped) {
      console.warn(
        `executePairedBuy: mirror pool quantity capped trader=${stableId} `
        + `requested=${mirrorPoolQuantity} allowed=${effectiveMirrorPoolQuantity} maxGross=${capResult.maxGrossAllowed}`,
      );
    }
  }

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
    if (status === 'CANCELLED') {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Paired execution was cancelled');
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

  await assertTraderCanOpenNewDepotPosition(stableId);

  const minTraderBuyAmount = await getMinTraderBuyOrderAmount();
  assertTraderBuyOrderMeetsMinimum(Number(traderQuantity) * executionPrice, minTraderBuyAmount);

  const execution = new PairedExecution();
  execution.set('traderId', stableId);
  execution.set('clientOrderIntentId', intentId);
  execution.set('symbol', symbol);
  execution.set('price', executionPrice);
  execution.set('priceSource', priceResolution.priceSource);
  if (priceResolution.clientSubmittedPrice != null) {
    execution.set('clientSubmittedPrice', priceResolution.clientSubmittedPrice);
  }
  execution.set('serverReferencePrice', priceResolution.serverReferencePrice);
  execution.set('priceSnapshotAt', priceResolution.priceSnapshotAt);
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
    order.set('price', executionPrice);
    order.set('totalAmount', Number(quantity) * executionPrice);
    order.set('status', 'submitted');
    order.set('executionPriceSource', priceResolution.priceSource);
    order.set('clientSubmittedPrice', priceResolution.clientSubmittedPrice);
    order.set('priceSnapshotAt', priceResolution.priceSnapshotAt);
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

  const legsToSave = [traderLeg];
  let mirrorLeg = null;
  if (effectiveMirrorPoolQuantity > 0) {
    mirrorLeg = createOrderLeg({
      quantity: effectiveMirrorPoolQuantity,
      legType: 'MIRROR_POOL',
      isMirrorPoolOrder: true,
    });
    legsToSave.push(mirrorLeg);
  }

  let savedLegs;
  try {
    // Save legs sequentially so beforeSave orderNumber generation cannot race (saveAll runs hooks in parallel).
    savedLegs = [];
    for (const leg of legsToSave) {
      await leg.save(null, { useMasterKey: true });
      savedLegs.push(leg);
    }
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

  // Orders remain at `submitted` until finalizePairedBuyExecution (paired legs stay in sync).
  // Cancellation via cancelOrder is allowed while effectsApplied is false (no trades/bookings yet).

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
