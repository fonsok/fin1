'use strict';

const { calculateOrderFees } = require('../helpers');
const { round2 } = require('./shared');

function resolveSellOrderGrossAmount(order) {
  return round2(Number(order?.totalAmount || 0));
}

function resolveSellOrderNetCashAmount(order, feeConfig = {}) {
  const gross = resolveSellOrderGrossAmount(order);
  if (!(gross > 0)) return 0;
  const fees = calculateOrderFees(gross, true, feeConfig);
  return round2(Math.max(0, gross - (fees.totalFees || 0)));
}

function getSellOrdersAddedSince(previousTrade, trade) {
  const prevKeys = new Set(
    getOrderArrayFromTradeLike(previousTrade)
      .map(resolveSellOrderKey)
      .filter(Boolean),
  );
  return getOrderArrayFromTradeLike(trade)
    .filter((order) => {
      const key = resolveSellOrderKey(order);
      return key && !prevKeys.has(key);
    });
}

function getTotalSellNetCashAmount(tradeLike, feeConfig = {}) {
  const orders = getOrderArrayFromTradeLike(tradeLike);
  return round2(
    orders.reduce((sum, order) => sum + resolveSellOrderNetCashAmount(order, feeConfig), 0),
  );
}

function getOrderArrayFromTradeLike(tradeLike) {
  if (!tradeLike) return [];
  const sellOrders = tradeLike.get ? (tradeLike.get('sellOrders') || []) : (tradeLike.sellOrders || []);
  const sellOrder = tradeLike.get ? tradeLike.get('sellOrder') : tradeLike.sellOrder;
  return sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
}

function getTotalSellAmount(tradeLike) {
  const orders = getOrderArrayFromTradeLike(tradeLike);
  return round2(orders.reduce((sum, order) => sum + Number(order?.totalAmount || 0), 0));
}

function getTotalSellQuantity(tradeLike) {
  const orders = getOrderArrayFromTradeLike(tradeLike);
  return round2(orders.reduce((sum, order) => sum + Number(order?.quantity || 0), 0));
}

function getRepresentativeSellOrder(tradeLike) {
  const orders = getOrderArrayFromTradeLike(tradeLike);
  return orders.length > 0 ? orders[orders.length - 1] : null;
}

/** Stable idempotency key for a sell order leg (partial or full). */
function resolveSellOrderKey(order) {
  if (!order) return '';
  return String(order.id || order.objectId || order.orderId || '').trim();
}

function findSellOrderByKey(tradeLike, sellOrderId) {
  const key = String(sellOrderId || '').trim();
  if (!key) return null;
  return getOrderArrayFromTradeLike(tradeLike).find((o) => resolveSellOrderKey(o) === key) || null;
}

function orderMatchesBelegLeg(order, { grossAmount, quantity } = {}) {
  const gross = round2(Number(grossAmount) || 0);
  const qty = round2(Number(quantity) || 0);
  const orderGross = resolveSellOrderGrossAmount(order);
  const orderQty = round2(Number(order.quantity || order.executedQuantity || 0));
  if (gross > 0 && orderGross > 0 && Math.abs(orderGross - gross) > 0.02) return false;
  if (qty > 0 && orderQty > 0 && Math.abs(orderQty - qty) > 0.001) return false;
  return true;
}

/**
 * Resolve the sell order leg for one trader TSC beleg (backfill / repair).
 * Prefers persisted sellOrderId when it matches amount/qty; else unique gross or quantity match.
 */
function findSellOrderForBelegLeg(tradeLike, { sellOrderId, grossAmount, quantity } = {}) {
  const byKey = findSellOrderByKey(tradeLike, sellOrderId);
  if (byKey && orderMatchesBelegLeg(byKey, { grossAmount, quantity })) {
    return byKey;
  }

  const orders = getOrderArrayFromTradeLike(tradeLike);
  const gross = round2(Number(grossAmount) || 0);
  const qty = round2(Number(quantity) || 0);

  if (gross > 0) {
    const byGross = orders.filter((o) => {
      const og = resolveSellOrderGrossAmount(o);
      return og > 0 && Math.abs(og - gross) <= 0.02;
    });
    if (byGross.length === 1) return byGross[0];
  }

  if (qty > 0) {
    const byQty = orders.filter((o) => {
      const oq = round2(Number(o.quantity || o.executedQuantity || 0));
      return oq > 0 && Math.abs(oq - qty) <= 0.001;
    });
    if (byQty.length === 1) return byQty[0];
  }

  return null;
}

function computeTradingFees(trade) {
  return computeTradingFeesWithBreakdown(trade).totalFees;
}

function computeTradingFeesWithBreakdown(trade) {
  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  const breakdown = { orderFee: 0, exchangeFee: 0, foreignCosts: 0 };

  function addOrderFees(orderAmount) {
    const fees = calculateOrderFees(orderAmount, true);
    breakdown.orderFee += fees.orderFee || 0;
    breakdown.exchangeFee += fees.exchangeFee || 0;
    breakdown.foreignCosts += fees.foreignCosts || 0;
  }

  if (buyOrder) addOrderFees(buyOrder.totalAmount || 0);
  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
  for (const so of allSells) addOrderFees(so.totalAmount || 0);

  breakdown.orderFee = round2(breakdown.orderFee);
  breakdown.exchangeFee = round2(breakdown.exchangeFee);
  breakdown.foreignCosts = round2(breakdown.foreignCosts);
  const totalFees = round2(breakdown.orderFee + breakdown.exchangeFee + breakdown.foreignCosts);

  return { totalFees, breakdown };
}

module.exports = {
  computeTradingFees,
  computeTradingFeesWithBreakdown,
  getOrderArrayFromTradeLike,
  getTotalSellAmount,
  getTotalSellNetCashAmount,
  getTotalSellQuantity,
  getRepresentativeSellOrder,
  getSellOrdersAddedSince,
  resolveSellOrderGrossAmount,
  resolveSellOrderNetCashAmount,
  resolveSellOrderKey,
  findSellOrderByKey,
  findSellOrderForBelegLeg,
};
