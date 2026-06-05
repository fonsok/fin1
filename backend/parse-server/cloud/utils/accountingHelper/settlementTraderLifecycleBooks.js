'use strict';

const { round2 } = require('./shared');
const { bookSettlementEntry } = require('./statements');
const { createTradeExecutionDocument } = require('./documents');
const { ensurePoolMirrorExecutionEigenbelegDocument } = require('./poolMirrorExecutionEigenbelegBook');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  findExistingStatementEntry,
  findExistingTraderTradeCashEntry,
  resolveLedgerUserKeysForUserId,
  sumStatementAmounts,
} = require('./settlementQueries');
const { getTotalSellAmount } = require('./settlementTradeMath');
const { isMirrorPoolTradeLeg } = require('../../services/poolMirrorActivation/poolActivationPolicy');

/**
 * Trader cash legs at settlement time: trade_buy, trade_sell (per leg), trading_fees.
 * Idempotent via findExistingStatementEntry checks.
 */
async function bookTraderTradeLifecycleEntries({
  trade,
  traderId,
  tradeNumber,
  totalTradingFees,
  tradingFeeBreakdown,
  businessCaseId,
}) {
  if (isMirrorPoolTradeLeg(trade)) {
    return;
  }

  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);

  if (buyOrder && buyOrder.totalAmount > 0) {
    const existingTradeBuy = await findExistingTraderTradeCashEntry({
      userId: traderId,
      tradeId: trade.id,
      tradeNumber,
      entryType: 'trade_buy',
      businessCaseId,
      pairExecutionId: trade.get('pairExecutionId'),
    });
    if (!existingTradeBuy) {
      const buyDoc = await createTradeExecutionDocument({
        traderId, trade, executionType: 'buy',
        amount: buyOrder.totalAmount, order: buyOrder,
        businessCaseId,
      });
      try {
        await ensurePoolMirrorExecutionEigenbelegDocument({
          traderTrade: trade,
          traderExecutionDoc: buyDoc,
          executionType: 'buy',
        });
      } catch (_) { /* non-blocking */ }
      const buyDocRef = resolveDocumentReference(buyDoc, { context: 'trade_buy' });
      await bookSettlementEntry({
        userId: traderId,
        userRole: 'trader',
        entryType: 'trade_buy',
        amount: -Math.abs(round2(buyOrder.totalAmount)),
        tradeId: trade.id,
        tradeNumber,
        description: `Wertpapierkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
        ...buyDocRef,
        businessCaseId,
      });
    }
  }

  const targetSellTotal = getTotalSellAmount(trade);
  const traderUserKeys = await resolveLedgerUserKeysForUserId(traderId);
  const bookedSellTotal = await sumStatementAmounts({
    userKeys: traderUserKeys,
    tradeId: trade.id,
    entryType: 'trade_sell',
    absolute: true,
  });
  const sellRemaining = round2(targetSellTotal - bookedSellTotal);
  if (sellRemaining > 0.005) {
    const representativeOrder = allSells.find((so) => so && so.totalAmount > 0) || allSells[0] || {};
    const docOrder = Object.assign({}, representativeOrder, { totalAmount: sellRemaining });
    const sellDoc = await createTradeExecutionDocument({
      traderId, trade, executionType: 'sell',
      amount: sellRemaining, order: docOrder,
      businessCaseId,
    });
    try {
      await ensurePoolMirrorExecutionEigenbelegDocument({
        traderTrade: trade,
        traderExecutionDoc: sellDoc,
        executionType: 'sell',
      });
    } catch (_) { /* non-blocking */ }
    const sellDocRef = resolveDocumentReference(sellDoc, { context: 'trade_sell' });
    await bookSettlementEntry({
      userId: traderId,
      userRole: 'trader',
      entryType: 'trade_sell',
      amount: sellRemaining,
      tradeId: trade.id,
      tradeNumber,
      description: `Wertpapierverkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
      ...sellDocRef,
      businessCaseId,
    });
  }

  if (totalTradingFees > 0) {
    const existingFees = await findExistingStatementEntry({
      userId: traderId,
      tradeId: trade.id,
      entryType: 'trading_fees',
    });
    if (!existingFees) {
      const feeDoc = await createTradeExecutionDocument({
        traderId, trade, executionType: 'fees',
        amount: totalTradingFees, order: buyOrder,
        businessCaseId,
        feeBreakdown: tradingFeeBreakdown,
      });
      const feeDocRef = resolveDocumentReference(feeDoc, { context: 'trading_fees' });
      await bookSettlementEntry({
        userId: traderId,
        userRole: 'trader',
        entryType: 'trading_fees',
        amount: -round2(totalTradingFees),
        tradeId: trade.id,
        tradeNumber,
        description: `Handelsgebühren Trade #${tradeNumber}`,
        ...feeDocRef,
        feeBreakdown: tradingFeeBreakdown,
        businessCaseId,
      });
    }
  }
}

module.exports = {
  bookTraderTradeLifecycleEntries,
};
