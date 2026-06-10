'use strict';

const {
  totalSellAmount,
  totalSellQuantity,
} = require('./tradeSellQuantityHelpers');

function resolveBuyTotal(tradeLike) {
  const buyOrder = tradeLike.get ? tradeLike.get('buyOrder') : tradeLike.buyOrder;
  const buyAmount = tradeLike.get ? tradeLike.get('buyAmount') : tradeLike.buyAmount;
  return Number(buyOrder?.totalAmount || buyAmount || 0);
}

function resolveBuyQuantity(tradeLike) {
  const buyOrder = tradeLike.get ? tradeLike.get('buyOrder') : tradeLike.buyOrder;
  const quantity = tradeLike.get ? tradeLike.get('quantity') : tradeLike.quantity;
  return Number(quantity || buyOrder?.quantity || 0);
}

/**
 * Realized gross profit SSOT for trader trades.
 * Full sell:  sellTotal − buyTotal
 * Partial:    sellTotal − buyTotal × (soldQty / buyQty)
 *
 * @returns {number|null} null when legs are insufficient
 */
function resolveTradeRealizedGrossProfit(tradeLike) {
  const buyTotal = resolveBuyTotal(tradeLike);
  const buyQty = resolveBuyQuantity(tradeLike);
  const sellTotal = totalSellAmount(tradeLike);
  const soldQty = totalSellQuantity(tradeLike);

  if (buyTotal <= 0 || sellTotal <= 0 || soldQty <= 0 || buyQty <= 0) {
    return null;
  }

  const allocatedBuyCost = soldQty >= buyQty
    ? buyTotal
    : (buyTotal * soldQty) / buyQty;

  return sellTotal - allocatedBuyCost;
}

module.exports = {
  resolveTradeRealizedGrossProfit,
  resolveBuyTotal,
  resolveBuyQuantity,
};
