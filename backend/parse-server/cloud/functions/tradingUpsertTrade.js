'use strict';

const { getUserStableId } = require('./tradingIdentity');
const { assertProductAccessEligible } = require('../utils/productAccessGate');

const PARSE_OBJECT_ID_PATTERN = /^[A-Za-z0-9]{10}$/;

async function allocateNextTradeNumberForTrader(traderId) {
  const q = new Parse.Query('Trade');
  q.equalTo('traderId', traderId);
  q.descending('tradeNumber');
  q.limit(1);
  const last = await q.first({ useMasterKey: true });
  const lastNumber = Number(last?.get('tradeNumber') || 0);
  return Number.isFinite(lastNumber) ? lastNumber + 1 : 1;
}

async function resolveTradeForUpsert(Trade, stableId, trade) {
  const incomingObjectId = String(trade.objectId || '').trim();
  if (PARSE_OBJECT_ID_PATTERN.test(incomingObjectId)) {
    try {
      const byId = await new Parse.Query(Trade).get(incomingObjectId, { useMasterKey: true });
      if (byId.get('traderId') === stableId || !byId.get('traderId')) {
        return byId;
      }
    } catch (_) {
      void _;
    }
  }

  const buyOrderId = String(trade.buyOrderId || trade.buyOrder?.id || '').trim();
  if (buyOrderId) {
    const byBuyOrder = await new Parse.Query(Trade)
      .equalTo('buyOrderId', buyOrderId)
      .equalTo('traderId', stableId)
      .first({ useMasterKey: true });
    if (byBuyOrder) return byBuyOrder;
  }

  if (Number.isFinite(trade.tradeNumber)) {
    const byNumber = await new Parse.Query(Trade)
      .equalTo('traderId', stableId)
      .equalTo('tradeNumber', trade.tradeNumber)
      .first({ useMasterKey: true });
    if (byNumber) return byNumber;
  }

  return new Trade();
}

async function handleUpsertTrade(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  await assertProductAccessEligible(user);

  const stableId = getUserStableId(user);
  const { trade } = request.params || {};
  if (!trade || typeof trade !== 'object') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'trade payload required');
  }

  const Trade = Parse.Object.extend('Trade');
  const target = await resolveTradeForUpsert(Trade, stableId, trade);
  const isNewTrade = !target.id;

  const existingTraderId = target.get('traderId');
  if (existingTraderId && existingTraderId !== stableId && !request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Access denied');
  }

  if (isNewTrade) {
    const nextTradeNumber = await allocateNextTradeNumberForTrader(stableId);
    target.set('tradeNumber', nextTradeNumber);
  } else if (Number.isFinite(trade.tradeNumber)) {
    target.set('tradeNumber', trade.tradeNumber);
  }

  if (typeof trade.symbol === 'string') target.set('symbol', trade.symbol);
  if (typeof trade.description === 'string') target.set('description', trade.description);
  if (Number.isFinite(trade.calculatedProfit)) target.set('calculatedProfit', trade.calculatedProfit);
  if (trade.buyOrder && typeof trade.buyOrder === 'object') {
    target.set('buyOrder', trade.buyOrder);
    const buyOrderId = String(trade.buyOrderId || trade.buyOrder.id || '').trim();
    if (buyOrderId) target.set('buyOrderId', buyOrderId);
  } else {
    const buyOrderId = String(trade.buyOrderId || '').trim();
    if (buyOrderId) target.set('buyOrderId', buyOrderId);
  }
  if (trade.sellOrder && typeof trade.sellOrder === 'object') target.set('sellOrder', trade.sellOrder);
  if (Array.isArray(trade.sellOrders)) target.set('sellOrders', trade.sellOrders);

  const effectiveBuyOrder = (trade.buyOrder && typeof trade.buyOrder === 'object')
    ? trade.buyOrder
    : (target.get('buyOrder') || {});
  const buyQty = Number(trade.quantity || effectiveBuyOrder.quantity || target.get('quantity') || 0);

  const effectiveSellOrders = Array.isArray(trade.sellOrders)
    ? trade.sellOrders
    : (target.get('sellOrders') || []);
  const effectiveSellOrder = (trade.sellOrder && typeof trade.sellOrder === 'object')
    ? trade.sellOrder
    : target.get('sellOrder');
  const sellOrdersList = effectiveSellOrders.length > 0
    ? effectiveSellOrders
    : (effectiveSellOrder ? [effectiveSellOrder] : []);
  const soldQtyDerived = sellOrdersList.reduce((sum, order) => sum + Number(order?.quantity || 0), 0);

  if (buyQty > 0) {
    if (soldQtyDerived > buyQty) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        `Ungültige Trade-Menge: Sell (${soldQtyDerived}) darf Buy (${buyQty}) nicht überschreiten.`,
      );
    }
    target.set('quantity', buyQty);
    target.set('soldQuantity', Math.max(0, soldQtyDerived));
    target.set('remainingQuantity', Math.max(0, buyQty - soldQtyDerived));
  }

  if (typeof trade.status === 'string') {
    const requestedStatus = trade.status;
    if (requestedStatus === 'completed' && buyQty > 0 && soldQtyDerived !== buyQty) {
      target.set('status', soldQtyDerived > 0 ? 'partial' : 'active');
    } else {
      target.set('status', requestedStatus);
      if (requestedStatus === 'completed' && trade.completedAt) target.set('completedAt', trade.completedAt);
    }
  } else if (buyQty > 0) {
    if (soldQtyDerived === buyQty && soldQtyDerived > 0) {
      target.set('status', 'completed');
    } else if (soldQtyDerived > 0) {
      target.set('status', 'partial');
    }
  }

  target.set('traderId', stableId);
  await target.save(null, { useMasterKey: true });
  return target.toJSON();
}

module.exports = {
  handleUpsertTrade,
  allocateNextTradeNumberForTrader,
  resolveTradeForUpsert,
};
