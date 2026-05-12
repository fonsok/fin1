'use strict';

const { round2 } = require('./shared');
const { bookSettlementEntry } = require('./statements');
const { createTradeExecutionDocument } = require('./documents');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const { findExistingStatementEntry } = require('./settlementQueries');

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
  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);

  if (buyOrder && buyOrder.totalAmount > 0) {
    const existingTradeBuy = await findExistingStatementEntry({
      userId: traderId,
      tradeId: trade.id,
      entryType: 'trade_buy',
    });
    if (!existingTradeBuy) {
      const buyDoc = await createTradeExecutionDocument({
        traderId, trade, executionType: 'buy',
        amount: buyOrder.totalAmount, order: buyOrder,
        businessCaseId,
      });
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

  const hasExistingTradeSell = await findExistingStatementEntry({
    userId: traderId,
    tradeId: trade.id,
    entryType: 'trade_sell',
  });
  if (!hasExistingTradeSell) {
    for (const so of allSells) {
      if (so && so.totalAmount > 0) {
        const sellDoc = await createTradeExecutionDocument({
          traderId, trade, executionType: 'sell',
          amount: so.totalAmount, order: so,
          businessCaseId,
        });
        const sellDocRef = resolveDocumentReference(sellDoc, { context: 'trade_sell' });
        await bookSettlementEntry({
          userId: traderId,
          userRole: 'trader',
          entryType: 'trade_sell',
          amount: round2(so.totalAmount),
          tradeId: trade.id,
          tradeNumber,
          description: `Wertpapierverkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
          ...sellDocRef,
          businessCaseId,
        });
      }
    }
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
