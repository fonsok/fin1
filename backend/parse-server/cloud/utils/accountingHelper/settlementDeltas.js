'use strict';

const { loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { bookSettlementEntry } = require('./statements');
const { createTradeExecutionDocument, findExistingTradeExecutionDocument } = require('./documents');
const { ensurePoolMirrorExecutionEigenbelegDocument } = require('./poolMirrorExecutionEigenbelegBook');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  getSellOrdersAddedSince,
  resolveSellOrderGrossAmount,
  resolveSellOrderNetCashAmount,
  resolveSellOrderKey,
} = require('./settlementTradeMath');
const {
  findExistingTraderTradeCashEntry,
  findExistingStatementEntry,
} = require('./settlementQueries');
const { isMirrorPoolTradeLeg } = require('../../services/poolMirrorActivation/poolActivationPolicy');
const { customerDisplayFromPersistedBelegMetadata } = require('./traderStatementCustomerDisplay');

/**
 * Books one trader sell leg: external TSC (Kurswert + Gebühren) + internal pool-mirror eigenbeleg,
 * Kontoauszug trade_sell = net cash (Σ VERKAUF), idempotent per sellOrderId.
 */
async function bookTraderSellOrderLeg({
  traderId,
  trade,
  tradeNumber,
  order,
  businessCaseId,
  feeConfig,
}) {
  const sellOrderId = resolveSellOrderKey(order);
  const grossAmount = resolveSellOrderGrossAmount(order);
  if (!traderId || !trade?.id || !(grossAmount > 0) || !sellOrderId) {
    return null;
  }

  const resolvedBusinessCaseId = businessCaseId || await ensureBusinessCaseIdForTrade(trade);
  const existingDoc = await findExistingTradeExecutionDocument({
    tradeId: trade.id,
    executionType: 'sell',
    businessCaseId: resolvedBusinessCaseId,
    sellOrderId,
  });

  const executionResult = existingDoc
    ? { document: existingDoc }
    : await createTradeExecutionDocument({
      traderId,
      trade,
      executionType: 'sell',
      amount: grossAmount,
      order,
      businessCaseId: resolvedBusinessCaseId,
      sellOrderId,
    });
  const sellDoc = executionResult.document;
  const customerDisplaySnapshot = executionResult.customerDisplay
    || customerDisplayFromPersistedBelegMetadata(sellDoc.get('metadata'), 'sell');

  const sellDocRef = resolveDocumentReference(sellDoc, { context: 'trade_sell_delta' });
  if (sellDocRef.referenceDocumentId) {
    const existingStmt = await findExistingStatementEntry({
      userId: traderId,
      tradeId: trade.id,
      entryType: 'trade_sell',
      referenceDocumentId: sellDocRef.referenceDocumentId,
    });
    if (existingStmt) {
      return existingStmt;
    }
  }

  try {
    await ensurePoolMirrorExecutionEigenbelegDocument({
      traderTrade: trade,
      traderExecutionDoc: sellDoc,
      executionType: 'sell',
      sellOrderId,
    });
  } catch (_) {
    // Pool eigenbeleg must not block trader booking
  }

  const netCash = resolveSellOrderNetCashAmount(order, feeConfig);
  return bookSettlementEntry({
    userId: traderId,
    userRole: 'trader',
    entryType: 'trade_sell',
    amount: netCash,
    tradeId: trade.id,
    tradeNumber,
    description: `Wertpapierverkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
    ...sellDocRef,
    businessCaseId: resolvedBusinessCaseId,
    customerDisplaySnapshot,
  });
}

async function bookTraderBuyEntryIfMissing(trade) {
  if (isMirrorPoolTradeLeg(trade)) {
    return null;
  }

  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const buyOrder = trade.get('buyOrder') || {};
  const buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);

  if (!traderId || !trade.id || !Number.isFinite(buyAmount) || buyAmount <= 0) {
    return null;
  }

  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);
  const existing = await findExistingTraderTradeCashEntry({
    userId: traderId,
    tradeId: trade.id,
    tradeNumber,
    entryType: 'trade_buy',
    businessCaseId,
    pairExecutionId: trade.get('pairExecutionId'),
  });
  if (existing) {
    try {
      await ensurePoolMirrorExecutionEigenbelegDocument({
        traderTrade: trade,
        traderExecutionDoc: null,
        executionType: 'buy',
      });
    } catch (_) {
      // Pool eigenbeleg must not block trader booking idempotency
    }
    return existing;
  }

  const { document: buyDoc, customerDisplay: buyCustomerDisplay } = await createTradeExecutionDocument({
    traderId,
    trade,
    executionType: 'buy',
    amount: buyAmount,
    order: buyOrder,
    businessCaseId,
  });
  try {
    await ensurePoolMirrorExecutionEigenbelegDocument({
      traderTrade: trade,
      traderExecutionDoc: buyDoc,
      executionType: 'buy',
    });
  } catch (_) {
    // Pool eigenbeleg must not block trader booking
  }
  const buyDocRef = resolveDocumentReference(buyDoc, { context: 'trade_buy_delta' });

  return bookSettlementEntry({
    userId: traderId,
    userRole: 'trader',
    entryType: 'trade_buy',
    amount: -Math.abs(round2(buyAmount)),
    tradeId: trade.id,
    tradeNumber,
    description: `Wertpapierkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
    ...buyDocRef,
    businessCaseId,
    customerDisplaySnapshot: buyCustomerDisplay,
  });
}

async function bookTraderSellDeltaIfAny({ trade, previousTrade }) {
  if (!trade || !previousTrade) return null;
  if (isMirrorPoolTradeLeg(trade)) {
    return null;
  }

  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const newOrders = getSellOrdersAddedSince(previousTrade, trade);
  if (!traderId || !trade.id || !newOrders.length) {
    return null;
  }

  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);
  const config = await loadConfig();
  const feeConfig = config.financial || {};

  let lastResult = null;
  for (const order of newOrders) {
    const result = await bookTraderSellOrderLeg({
      traderId,
      trade,
      tradeNumber,
      order,
      businessCaseId,
      feeConfig,
    });
    if (result) lastResult = result;
  }
  return lastResult;
}

const {
  bookInvestorPartialRealizationDeltaIfAny,
} = require('./settlementInvestorPartialRealization');

module.exports = {
  bookTraderBuyEntryIfMissing,
  bookTraderSellOrderLeg,
  bookTraderSellDeltaIfAny,
  bookInvestorPartialRealizationDeltaIfAny,
};
