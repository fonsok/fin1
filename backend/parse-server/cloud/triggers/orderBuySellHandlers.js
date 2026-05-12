'use strict';

const { buildBuyOrderSnapshotFromOrder } = require('./orderBuySnapshot');
const { allocateTradeToInvestmentPools } = require('./orderPoolAllocation');

async function handleBuyOrderExecuted(order) {
  const existing = await new Parse.Query('Trade')
    .equalTo('buyOrderId', order.id)
    .first({ useMasterKey: true });

  let savedTrade = existing;

  const buySnap = buildBuyOrderSnapshotFromOrder(order);

  if (!existing) {
    const Trade = Parse.Object.extend('Trade');
    const trade = new Trade();

    trade.set('traderId', order.get('traderId'));
    trade.set('buyOrderId', order.id);
    trade.set('symbol', order.get('symbol'));
    trade.set('securityName', order.get('securityName'));
    trade.set('securityType', order.get('securityType'));
    trade.set('wkn', order.get('wkn'));
    trade.set('quantity', order.get('executedQuantity'));
    trade.set('buyPrice', order.get('price'));
    trade.set('buyAmount', order.get('grossAmount'));
    trade.set('buyOrder', buySnap);
    trade.set('status', 'active');
    trade.set('openedAt', new Date());

    savedTrade = await trade.save(null, { useMasterKey: true });

    order.set('tradeId', savedTrade.id);
    await order.save(null, { useMasterKey: true });
  } else {
    savedTrade = existing;
    if (!existing.get('buyOrder')) {
      existing.set('buyOrder', buySnap);
      savedTrade = await existing.save(null, { useMasterKey: true });
    }
    if (!order.get('tradeId')) {
      order.set('tradeId', savedTrade.id);
      await order.save(null, { useMasterKey: true });
    }
  }

  const skipPoolAllocation = order.get('legType') === 'TRADER';

  if (!skipPoolAllocation && savedTrade) {
    await allocateTradeToInvestmentPools(savedTrade);
  }
}

async function handleSellOrderExecuted(order) {
  const tradeId = order.get('tradeId');
  if (!tradeId) return;

  const Trade = Parse.Object.extend('Trade');
  const trade = await new Parse.Query(Trade).get(tradeId, { useMasterKey: true });

  if (!trade) return;

  const sellQuantity = order.get('executedQuantity');
  const sellPrice = order.get('price');
  const sellAmount = order.get('grossAmount');

  const newSoldQuantity = (trade.get('soldQuantity') || 0) + sellQuantity;
  trade.set('soldQuantity', newSoldQuantity);

  const buyPrice = trade.get('buyPrice');
  const profitPerUnit = sellPrice - buyPrice;
  const grossProfit = profitPerUnit * sellQuantity;

  const totalSellAmount = (trade.get('sellAmount') || 0) + sellAmount;
  const totalGrossProfit = (trade.get('grossProfit') || 0) + grossProfit;

  trade.set('sellAmount', totalSellAmount);
  trade.set('grossProfit', totalGrossProfit);
  trade.set('averageSellPrice', totalSellAmount / newSoldQuantity);

  const buyAmount = trade.get('buyAmount');
  if (buyAmount > 0) {
    trade.set('profitPercentage', (totalGrossProfit / buyAmount) * 100);
  }

  await trade.save(null, { useMasterKey: true });
}

module.exports = {
  handleBuyOrderExecuted,
  handleSellOrderExecuted,
};
