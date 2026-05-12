'use strict';

function resolveSellOrdersFromParseTrade(tradeObj) {
  const sellOrders = tradeObj.get('sellOrders') || [];
  const sellOrder = tradeObj.get('sellOrder');
  return sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
}

function deriveSoldQuantity(tradeObj) {
  return resolveSellOrdersFromParseTrade(tradeObj).reduce((sum, order) => sum + Number(order?.quantity || 0), 0);
}

/** Supports Parse.Object or plain `{ sellOrders, sellOrder }`. */
function resolveSellOrdersFromTradeLike(tradeLike) {
  const sellOrders = tradeLike.get ? (tradeLike.get('sellOrders') || []) : (tradeLike.sellOrders || []);
  const sellOrder = tradeLike.get ? tradeLike.get('sellOrder') : tradeLike.sellOrder;
  return sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
}

function totalSellQuantity(tradeLike) {
  return resolveSellOrdersFromTradeLike(tradeLike).reduce((sum, order) => sum + Number(order?.quantity || 0), 0);
}

function totalSellAmount(tradeLike) {
  return resolveSellOrdersFromTradeLike(tradeLike).reduce((sum, order) => sum + Number(order?.totalAmount || 0), 0);
}

module.exports = {
  resolveSellOrdersFromParseTrade,
  deriveSoldQuantity,
  resolveSellOrdersFromTradeLike,
  totalSellQuantity,
  totalSellAmount,
};
