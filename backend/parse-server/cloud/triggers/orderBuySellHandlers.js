'use strict';

const { buildBuyOrderSnapshotFromOrder } = require('./orderBuySnapshot');
const { buildSellOrderSnapshotFromOrder } = require('./orderSellSnapshot');
const { allocateTradeToInvestmentPools } = require('./orderPoolAllocation');
const { isMirrorPoolOrderLeg } = require('../services/poolMirrorActivation/poolActivationPolicy');
const { pairedStatusBatchContext } = require('../utils/pairedOrderShared');

async function resolveTradeIdForSellOrder(order) {
  const existing = String(order.get('tradeId') || '').trim();
  if (existing) return existing;

  const holdingId = String(order.get('originalHoldingId') || '').trim();
  if (!holdingId) return null;

  const byBuyOrderId = await new Parse.Query('Trade')
    .equalTo('buyOrderId', holdingId)
    .first({ useMasterKey: true });
  if (byBuyOrderId) return byBuyOrderId.id;

  try {
    const byTradeId = await new Parse.Query('Trade').get(holdingId, { useMasterKey: true });
    if (byTradeId) return byTradeId.id;
  } catch (_) {
    void _;
  }

  return null;
}

function applyPairedLegFieldsToTrade(trade, order, buySnap) {
  let dirty = false;
  const legType = String(order.get('legType') || '').trim();
  if (legType && trade.get('buyLegType') !== legType) {
    trade.set('buyLegType', legType);
    dirty = true;
  }
  const pairExecutionId = String(order.get('pairExecutionId') || '').trim();
  if (pairExecutionId && trade.get('pairExecutionId') !== pairExecutionId) {
    trade.set('pairExecutionId', pairExecutionId);
    dirty = true;
  }
  if (!String(trade.get('buyOrderId') || '').trim()) {
    trade.set('buyOrderId', order.id);
    dirty = true;
  }
  if (!trade.get('buyOrder')) {
    trade.set('buyOrder', buySnap);
    dirty = true;
  }
  const qty = Number(order.get('executedQuantity') || order.get('quantity') || 0);
  if (qty > 0 && Number(trade.get('quantity') || 0) !== qty) {
    trade.set('quantity', qty);
    trade.set('remainingQuantity', qty);
    dirty = true;
  }
  const grossAmount = Number(order.get('grossAmount') || 0);
  if (grossAmount > 0 && Number(trade.get('buyAmount') || 0) !== grossAmount) {
    trade.set('buyAmount', grossAmount);
    dirty = true;
  }
  const price = Number(order.get('price') || 0);
  if (price > 0 && Number(trade.get('buyPrice') || 0) !== price) {
    trade.set('buyPrice', price);
    dirty = true;
  }
  return dirty;
}

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
    trade.set('description', order.get('description') || order.get('securityName') || order.get('symbol'));
    trade.set('securityName', order.get('securityName'));
    trade.set('securityType', order.get('securityType'));
    trade.set('wkn', order.get('wkn'));
    trade.set('quantity', order.get('executedQuantity'));
    trade.set('buyPrice', order.get('price'));
    trade.set('buyAmount', order.get('grossAmount'));
    trade.set('buyOrder', buySnap);
    const legType = String(order.get('legType') || '').trim();
    if (legType) {
      trade.set('buyLegType', legType);
    }
    const pairExecutionId = String(order.get('pairExecutionId') || '').trim();
    if (pairExecutionId) {
      trade.set('pairExecutionId', pairExecutionId);
    }
    trade.set('status', 'active');
    trade.set('openedAt', new Date());

    savedTrade = await trade.save(null, { useMasterKey: true });

    order.set('tradeId', savedTrade.id);
    await order.save(null, { useMasterKey: true, context: pairedStatusBatchContext() });
  } else {
    savedTrade = existing;
    const dirty = applyPairedLegFieldsToTrade(existing, order, buySnap);
    if (dirty) {
      savedTrade = await existing.save(null, { useMasterKey: true });
    }
    if (!order.get('tradeId')) {
      order.set('tradeId', savedTrade.id);
      await order.save(null, { useMasterKey: true, context: pairedStatusBatchContext() });
    }
  }

  if (isMirrorPoolOrderLeg(order) && savedTrade) {
    await allocateTradeToInvestmentPools(savedTrade, order);
  }
}

async function handleSellOrderExecuted(order) {
  const tradeId = await resolveTradeIdForSellOrder(order);
  if (!tradeId) {
    console.warn(`handleSellOrderExecuted: no tradeId for sell order ${order.id}`);
    return;
  }

  if (!order.get('tradeId')) {
    order.set('tradeId', tradeId);
    await order.save(null, { useMasterKey: true });
  }

  const Trade = Parse.Object.extend('Trade');
  const trade = await new Parse.Query(Trade).get(tradeId, { useMasterKey: true });
  if (!trade) return;

  const sellQuantity = Number(order.get('executedQuantity') || order.get('quantity') || 0);
  if (sellQuantity <= 0) {
    console.warn(`handleSellOrderExecuted: zero sell quantity for order ${order.id}`);
    return;
  }

  const sellPrice = Number(order.get('price') || 0);
  const sellAmount = Number(order.get('grossAmount') || order.get('totalAmount') || sellQuantity * sellPrice);

  const sellSnap = buildSellOrderSnapshotFromOrder(order);
  const existingSellOrders = Array.isArray(trade.get('sellOrders')) ? [...trade.get('sellOrders')] : [];
  const orderKey = String(order.id);
  const alreadyRecorded = existingSellOrders.some((entry) => {
    const id = String(entry?.id || entry?.objectId || '').trim();
    return id === orderKey;
  });

  if (!alreadyRecorded) {
    existingSellOrders.push(sellSnap);
    trade.set('sellOrders', existingSellOrders);
  }

  const buyQty = Number(trade.get('quantity') || trade.get('buyOrder')?.quantity || 0);
  const soldFromOrders = existingSellOrders.reduce(
    (sum, entry) => sum + Number(entry?.quantity || 0),
    0,
  );
  const newSoldQuantity = soldFromOrders > 0 ? soldFromOrders : (Number(trade.get('soldQuantity') || 0) + sellQuantity);

  trade.set('soldQuantity', newSoldQuantity);
  trade.set('remainingQuantity', Math.max(0, buyQty - newSoldQuantity));

  const profitPerUnit = sellPrice - Number(trade.get('buyPrice') || 0);
  const grossProfit = profitPerUnit * sellQuantity;
  const totalSellAmount = (Number(trade.get('sellAmount') || 0) + sellAmount);
  const totalGrossProfit = (Number(trade.get('grossProfit') || 0) + grossProfit);

  trade.set('sellAmount', totalSellAmount);
  trade.set('grossProfit', totalGrossProfit);
  if (newSoldQuantity > 0) {
    trade.set('averageSellPrice', totalSellAmount / newSoldQuantity);
  }

  const buyAmount = Number(trade.get('buyAmount') || 0);
  if (buyAmount > 0) {
    trade.set('profitPercentage', (totalGrossProfit / buyAmount) * 100);
  }

  if (buyQty > 0 && newSoldQuantity >= buyQty) {
    trade.set('status', 'completed');
    trade.set('completedAt', new Date());
    trade.set('sellOrder', sellSnap);
  } else if (newSoldQuantity > 0) {
    trade.set('status', 'partial');
  }

  await trade.save(null, { useMasterKey: true });
}

module.exports = {
  handleBuyOrderExecuted,
  handleSellOrderExecuted,
  resolveTradeIdForSellOrder,
};
