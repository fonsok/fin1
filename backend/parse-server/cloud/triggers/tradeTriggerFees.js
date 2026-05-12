'use strict';

const { calculateOrderFees } = require('../utils/helpers');

function computeTradingFees(trade) {
  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  let total = 0;

  if (buyOrder) {
    total += calculateOrderFees(buyOrder.totalAmount || 0, true).totalFees;
  }

  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
  for (const so of allSells) {
    total += calculateOrderFees(so.totalAmount || 0, true).totalFees;
  }

  return total;
}

module.exports = {
  computeTradingFees,
};
