'use strict';

const { newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');
const { deriveSoldQuantity } = require('./tradeSellQuantityHelpers');
const { computeTradingFees } = require('./tradeTriggerFees');

Parse.Cloud.beforeSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !trade.existed();

  if (isNew) {
    if (!trade.get('businessCaseId')) {
      trade.set('businessCaseId', newBusinessCaseId());
    }
    if (!trade.get('tradeNumber')) {
      const lastTrade = await new Parse.Query('Trade')
        .descending('tradeNumber')
        .first({ useMasterKey: true });

      const nextNumber = lastTrade ? (lastTrade.get('tradeNumber') || 0) + 1 : 1;
      trade.set('tradeNumber', nextNumber);
    }

    if (!trade.get('status')) {
      trade.set('status', 'pending');
    }

    const buyOrder = trade.get('buyOrder');
    const directQuantity = trade.get('quantity');
    const quantity = directQuantity || (buyOrder ? buyOrder.quantity : 0);

    if (!trade.has('soldQuantity')) trade.set('soldQuantity', 0);
    if (!trade.has('remainingQuantity')) trade.set('remainingQuantity', quantity);

    const calculatedProfit = trade.get('calculatedProfit');
    if (calculatedProfit !== undefined && calculatedProfit !== null) {
      trade.set('grossProfit', calculatedProfit);

      const tradingFees = computeTradingFees(trade);
      trade.set('tradingFees', tradingFees);
      trade.set('totalFees', tradingFees);
      trade.set('netProfit', calculatedProfit - tradingFees);
      trade.set('profitPercentage', quantity > 0 ? (calculatedProfit / quantity) * 100 : 0);
    } else {
      if (!trade.has('grossProfit')) trade.set('grossProfit', 0);
      if (!trade.has('netProfit')) trade.set('netProfit', 0);
      if (!trade.has('totalFees')) trade.set('totalFees', 0);
      if (!trade.has('profitPercentage')) trade.set('profitPercentage', 0);
    }

    console.log(`📊 Trade beforeSave: New trade #${trade.get('tradeNumber')} status=${trade.get('status')} grossProfit=${trade.get('grossProfit')}`);
  }

  const buyOrderForQty = trade.get('buyOrder');
  const quantity = trade.get('quantity') || (buyOrderForQty ? buyOrderForQty.quantity : 0) || 0;
  const soldQuantityField = Number(trade.get('soldQuantity') || 0);
  const soldQuantityDerived = deriveSoldQuantity(trade);
  const soldQuantity = Math.max(soldQuantityField, soldQuantityDerived);
  if (quantity > 0 && soldQuantity > quantity) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      `Ungültige Trade-Menge: Sell (${soldQuantity}) darf Buy (${quantity}) nicht überschreiten.`,
    );
  }
  trade.set('soldQuantity', soldQuantity);
  trade.set('remainingQuantity', Math.max(0, quantity - soldQuantity));

  if (!isNew && request.original) {
    const oldStatus = request.original.get('status');

    const oldSold = Math.max(
      Number(request.original.get('soldQuantity') || 0),
      deriveSoldQuantity(request.original),
    );
    const newSold = Math.max(
      Number(trade.get('soldQuantity') || 0),
      deriveSoldQuantity(trade),
    );

    if (newSold > oldSold) {
      if (newSold === quantity) {
        trade.set('status', 'completed');
        trade.set('closedAt', new Date());
      } else if (newSold > 0) {
        trade.set('status', 'partial');
      }
    }

    const requestedStatus = String(trade.get('status') || '');
    if (requestedStatus === 'completed' && quantity > 0 && newSold < quantity) {
      trade.set('status', newSold > 0 ? 'partial' : oldStatus || 'active');
      trade.unset('closedAt');
      trade.unset('completedAt');
    }

    let calculatedProfit = trade.get('calculatedProfit');

    if (calculatedProfit === undefined || calculatedProfit === null || calculatedProfit === 0) {
      const buyOrder = trade.get('buyOrder');
      const sellOrder = trade.get('sellOrder');
      const sellOrders = trade.get('sellOrders') || [];

      const buyTotal = buyOrder ? (buyOrder.totalAmount || 0) : 0;
      let sellTotal = sellOrder ? (sellOrder.totalAmount || 0) : 0;
      if (sellOrders.length > 0) {
        sellTotal = sellOrders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
      }

      if (buyTotal > 0 && sellTotal > 0) {
        calculatedProfit = sellTotal - buyTotal;
        console.log(`📊 Trade update: Calculated profit from orders: ${sellTotal} - ${buyTotal} = ${calculatedProfit}`);
      }
    }

    if (calculatedProfit !== undefined && calculatedProfit !== null && calculatedProfit !== 0) {
      trade.set('grossProfit', calculatedProfit);
      trade.set('calculatedProfit', calculatedProfit);

      const tradingFees = computeTradingFees(trade);
      trade.set('tradingFees', tradingFees);
      trade.set('totalFees', tradingFees);
      trade.set('netProfit', calculatedProfit - tradingFees);
      console.log(`📊 Trade update: grossProfit=${calculatedProfit}, tradingFees=${tradingFees}, netProfit=${calculatedProfit - tradingFees}`);
    }
  }
});
