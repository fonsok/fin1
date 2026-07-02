'use strict';

const { newBusinessCaseId } = require('../utils/accountingHelper/businessCaseId');
const { deriveSoldQuantity } = require('./tradeSellQuantityHelpers');
const { resolveTradeRealizedGrossProfit } = require('./tradeRealizedGrossProfit');
const { computeTradingFees } = require('./tradeTriggerFees');
const {
  assertTraderPartialSellWithinLimit,
  countTraderPartialSellEvents,
} = require('../utils/configHelper/traderPartialSellLimits');
const {
  allocateNextTradeNumberForTrader,
  resolveTradeNumberYear,
} = require('../utils/tradeNumberAllocation');

Parse.Cloud.beforeSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !trade.existed();

  if (isNew) {
    if (!trade.get('businessCaseId')) {
      trade.set('businessCaseId', newBusinessCaseId());
    }
    const traderId = String(trade.get('traderId') || '').trim();
    if (traderId) {
      const existingNumber = Number(trade.get('tradeNumber'));
      const existingYear = Number(trade.get('tradeNumberYear'));
      const hasAuthoritativeNumber = Number.isFinite(existingNumber) && existingNumber > 0
        && Number.isFinite(existingYear) && existingYear > 0;
      if (!hasAuthoritativeNumber) {
        const allocation = await allocateNextTradeNumberForTrader(
          traderId,
          trade.get('createdAt') || new Date(),
        );
        trade.set('tradeNumber', allocation.tradeNumber);
        trade.set('tradeNumberYear', allocation.tradeNumberYear);
      }
    } else if (!trade.get('tradeNumber')) {
      const lastTrade = await new Parse.Query('Trade')
        .descending('tradeNumber')
        .first({ useMasterKey: true });
      const nextNumber = lastTrade ? (lastTrade.get('tradeNumber') || 0) + 1 : 1;
      trade.set('tradeNumber', nextNumber);
      trade.set('tradeNumberYear', resolveTradeNumberYear(trade));
    } else if (!trade.get('tradeNumberYear')) {
      trade.set('tradeNumberYear', resolveTradeNumberYear(trade));
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
  trade.set('traderPartialSellEventCount', countTraderPartialSellEvents(trade));

  const traderId = String(trade.get('traderId') || '').trim();
  const prevTraderId = isNew ? '' : String(request.original?.get('traderId') || '').trim();
  if (traderId && (isNew || traderId !== prevTraderId || !trade.get('traderName'))) {
    try {
      const { resolveTraderDisplayNameForBeleg } = require('../utils/traderDisplayNameForBeleg');
      const { traderDisplayName } = await resolveTraderDisplayNameForBeleg(traderId);
      if (traderDisplayName) trade.set('traderName', traderDisplayName);
    } catch (err) {
      console.warn('beforeSave Trade: traderName snapshot skipped:', err.message);
    }
  }

  const { buildTradeSearchBlob } = require('../utils/adminListSearch');
  trade.set('adminSearchBlob', buildTradeSearchBlob(trade));

  if (!isNew && request.original) {
    await assertTraderPartialSellWithinLimit(trade, request.original);

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

    const realizedGrossProfit = resolveTradeRealizedGrossProfit(trade);
    let calculatedProfit = trade.get('calculatedProfit');
    if (realizedGrossProfit !== null && Number.isFinite(realizedGrossProfit)) {
      calculatedProfit = realizedGrossProfit;
      console.log(`📊 Trade update: realized grossProfit=${calculatedProfit}`);
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

  if (trade.get('tradeNumber') && !trade.get('tradeNumberYear')) {
    trade.set('tradeNumberYear', resolveTradeNumberYear(trade));
  }
});
