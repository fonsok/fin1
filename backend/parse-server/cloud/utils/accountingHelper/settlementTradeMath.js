'use strict';

const { calculateOrderFees } = require('../helpers');
const { round2 } = require('./shared');

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
  getTotalSellQuantity,
  getRepresentativeSellOrder,
};
