'use strict';

function tradeSellVolume(trade) {
  const buyOrder = trade.get('buyOrder') || {};
  const sellOrder = trade.get('sellOrder') || {};
  const sellOrders = trade.get('sellOrders') || [];
  let sellVolume = sellOrder.totalAmount || 0;
  if (sellOrders.length > 0) {
    sellVolume = sellOrders.reduce((s, order) => s + (order.totalAmount || 0), 0);
  }
  if (sellVolume === 0 && buyOrder.totalAmount) {
    sellVolume = buyOrder.totalAmount;
  }
  return sellVolume;
}

function totalRevenueFromTrades(trades) {
  return trades.reduce((sum, trade) => sum + tradeSellVolume(trade), 0);
}

function totalFeesFromTrades(trades, commissionRate) {
  return trades.reduce((sum, trade) => {
    const profit = trade.get('calculatedProfit') || trade.get('grossProfit') || 0;
    const commission = profit > 0 ? profit * commissionRate : 0;
    return sum + commission;
  }, 0);
}

module.exports = {
  tradeSellVolume,
  totalRevenueFromTrades,
  totalFeesFromTrades,
};
