'use strict';

const { getUserStableId } = require('./tradingIdentity');
const { calculateOrderFees } = require('../utils/helpers');
const { resolveOrderExecutionPrice } = require('../utils/executionPriceResolver');
const { assertProductAccessEligible } = require('../utils/productAccessGate');

function formatSellOrderResponse(order, idempotentReplay) {
  return {
    orderId: order.id,
    orderNumber: order.get('orderNumber') || null,
    status: order.get('status') || null,
    executionPrice: Number(order.get('price') || 0),
    priceSource: order.get('executionPriceSource') || null,
    grossAmount: Number(order.get('grossAmount') || 0),
    totalFees: Number(order.get('totalFees') || 0),
    netAmount: Number(order.get('netAmount') || 0),
    idempotentReplay: !!idempotentReplay,
  };
}

/**
 * Server-orchestrated sell placement (ADR-019 Phase 1b).
 * Idempotent via clientOrderIntentId + traderId + side=sell.
 */
async function handleExecuteSellOrder(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader role required');
  }
  await assertProductAccessEligible(user);

  const {
    symbol,
    orderInstruction = 'market',
    limitPrice = null,
    clientOrderIntentId,
    quantity,
    tradeId = null,
    originalHoldingId = null,
    description = null,
    optionDirection = null,
    underlyingAsset = null,
    wkn = null,
    strike = null,
  } = request.params || {};

  if (!symbol || typeof symbol !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'symbol required');
  }
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'quantity must be an integer > 0');
  }
  if (!clientOrderIntentId || typeof clientOrderIntentId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'clientOrderIntentId required');
  }
  if (!['market', 'limit'].includes(String(orderInstruction).toLowerCase())) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'orderInstruction must be market or limit');
  }

  const stableId = getUserStableId(user);
  const intentId = clientOrderIntentId.trim();
  if (!intentId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'clientOrderIntentId must not be empty');
  }

  const existing = await new Parse.Query('Order')
    .equalTo('traderId', stableId)
    .equalTo('clientOrderIntentId', intentId)
    .equalTo('side', 'sell')
    .first({ useMasterKey: true });

  if (existing) {
    return formatSellOrderResponse(existing, true);
  }

  const instruction = String(orderInstruction).toLowerCase();
  const orderType = instruction === 'limit' ? 'limit' : 'market';

  const priceResolution = await resolveOrderExecutionPrice({
    symbol,
    orderType,
    limitPrice,
  });
  const executionPrice = priceResolution.executionPrice;

  const resolvedTradeId = String(tradeId || '').trim();
  if (resolvedTradeId) {
    const trade = await new Parse.Query('Trade').get(resolvedTradeId, { useMasterKey: true });
    if (!trade || String(trade.get('traderId') || '').trim() !== stableId) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');
    }
    const remaining = Number(trade.get('remainingQuantity') ?? trade.get('quantity') ?? 0);
    if (quantity > remaining) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Quantity exceeds available');
    }
  }

  const grossAmount = quantity * executionPrice;
  const fees = calculateOrderFees(grossAmount);

  const Order = Parse.Object.extend('Order');
  const order = new Order();
  order.set('traderId', stableId);
  order.set('symbol', symbol);
  order.set('description', description || symbol);
  order.set('type', 'sell');
  order.set('side', 'sell');
  order.set('orderType', orderType);
  order.set('orderInstruction', instruction);
  order.set('quantity', quantity);
  order.set('price', executionPrice);
  order.set('executionPriceSource', priceResolution.priceSource);
  if (priceResolution.clientSubmittedPrice != null) {
    order.set('clientSubmittedPrice', priceResolution.clientSubmittedPrice);
  }
  if (priceResolution.serverReferencePrice != null) {
    order.set('serverReferencePrice', priceResolution.serverReferencePrice);
  }
  if (priceResolution.priceSnapshotAt) {
    order.set('priceSnapshotAt', priceResolution.priceSnapshotAt);
  }
  if (priceResolution.clientQuotedAt) {
    order.set('clientQuotedAt', priceResolution.clientQuotedAt);
  }
  if (limitPrice != null) order.set('limitPrice', limitPrice);
  order.set('grossAmount', grossAmount);
  order.set('totalFees', fees.totalFees);
  order.set('totalAmount', grossAmount);
  order.set('netAmount', grossAmount - fees.totalFees);
  order.set('status', 'submitted');
  order.set('clientOrderIntentId', intentId);
  if (resolvedTradeId) order.set('tradeId', resolvedTradeId);
  if (originalHoldingId) order.set('originalHoldingId', originalHoldingId);
  if (optionDirection) order.set('optionDirection', optionDirection);
  order.set('underlyingAsset', underlyingAsset || description || symbol);
  order.set('wkn', wkn || symbol);
  if (strike != null) order.set('strike', strike);

  await order.save(null, { useMasterKey: true });

  return formatSellOrderResponse(order, false);
}

module.exports = {
  handleExecuteSellOrder,
  formatSellOrderResponse,
};
