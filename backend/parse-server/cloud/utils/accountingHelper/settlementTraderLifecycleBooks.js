'use strict';

const { loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { bookSettlementEntry } = require('./statements');
const { createTradeExecutionDocument, findExistingTradeExecutionDocument } = require('./documents');
const { ensurePoolMirrorExecutionEigenbelegDocument } = require('./poolMirrorExecutionEigenbelegBook');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  findExistingStatementEntry,
  findExistingTraderTradeCashEntry,
} = require('./settlementQueries');
const {
  getOrderArrayFromTradeLike,
  resolveSellOrderKey,
} = require('./settlementTradeMath');
const { bookTraderSellOrderLeg } = require('./settlementDeltas');
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
  const allSells = getOrderArrayFromTradeLike(trade);
  const config = await loadConfig();
  const feeConfig = config.financial || {};

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
      const { document: buyDoc, customerDisplay: buyCustomerDisplay } = await createTradeExecutionDocument({
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
        customerDisplaySnapshot: buyCustomerDisplay,
      });
    }
  }

  for (const order of allSells) {
    const sellOrderId = resolveSellOrderKey(order);
    if (!sellOrderId) continue;
    const existingDoc = await findExistingTradeExecutionDocument({
      tradeId: trade.id,
      executionType: 'sell',
      businessCaseId,
      sellOrderId,
    });
    if (existingDoc) {
      const docRef = resolveDocumentReference(existingDoc, { context: 'trade_sell' });
      const existingStmt = docRef.referenceDocumentId
        ? await findExistingStatementEntry({
          userId: traderId,
          tradeId: trade.id,
          entryType: 'trade_sell',
          referenceDocumentId: docRef.referenceDocumentId,
        })
        : null;
      if (existingStmt) continue;
    }
    await bookTraderSellOrderLeg({
      traderId,
      trade,
      tradeNumber,
      order,
      businessCaseId,
      feeConfig,
    });
  }

  if (totalTradingFees > 0) {
    const existingFees = await findExistingStatementEntry({
      userId: traderId,
      tradeId: trade.id,
      entryType: 'trading_fees',
    });
    if (!existingFees) {
      const { document: feeDoc } = await createTradeExecutionDocument({
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
