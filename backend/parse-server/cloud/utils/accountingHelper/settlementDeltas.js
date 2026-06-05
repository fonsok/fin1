'use strict';

const { getTraderCommissionRate, loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { bookAccountStatementEntry, bookSettlementEntry } = require('./statements');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('./taxation');
const { createCollectionBillDocument, createTradeExecutionDocument } = require('./documents');
const { ensurePoolMirrorExecutionEigenbelegDocument } = require('./poolMirrorExecutionEigenbelegBook');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  getTotalSellAmount,
  getTotalSellQuantity,
  getRepresentativeSellOrder,
} = require('./settlementTradeMath');
const {
  findExistingTraderTradeCashEntry,
  prefetchInvestmentsById,
  resolveLedgerUserKeysForUserId,
  sumStatementAmounts,
} = require('./settlementQueries');
const { findInvestment } = require('./settlementInvestmentFallback');
const { bookInvestorTaxEntries } = require('./settlementTaxEntries');
const { resolveTradeBuyPrice, resolveTradeSellPrice } = require('./shared');
const {
  resolvePoolContextForTraderSell,
  computeInvestorPartialSellDelta,
} = require('../poolMirrorEconomics');
const { isMirrorPoolTradeLeg } = require('../../services/poolMirrorActivation/poolActivationPolicy');

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

  const buyDoc = await createTradeExecutionDocument({
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
  });
}

async function bookTraderSellDeltaIfAny({ trade, previousTrade }) {
  if (!trade || !previousTrade) return null;
  if (isMirrorPoolTradeLeg(trade)) {
    return null;
  }

  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const currentSellAmount = getTotalSellAmount(trade);
  const previousSellAmount = getTotalSellAmount(previousTrade);
  let deltaSellAmount = round2(currentSellAmount - previousSellAmount);

  if (!traderId || !trade.id || !Number.isFinite(deltaSellAmount) || deltaSellAmount <= 0) {
    return null;
  }

  const userKeys = await resolveLedgerUserKeysForUserId(traderId);
  const bookedSellTotal = await sumStatementAmounts({
    userKeys,
    tradeId: trade.id,
    entryType: 'trade_sell',
    absolute: true,
  });
  const sellRemaining = round2(currentSellAmount - bookedSellTotal);
  if (sellRemaining <= 0.005) {
    return null;
  }
  deltaSellAmount = round2(Math.min(deltaSellAmount, sellRemaining));
  if (deltaSellAmount <= 0) {
    return null;
  }

  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const representativeOrder = getRepresentativeSellOrder(trade) || {};
  const docOrder = Object.assign({}, representativeOrder, { totalAmount: deltaSellAmount });
  const sellDoc = await createTradeExecutionDocument({
    traderId,
    trade,
    executionType: 'sell',
    amount: deltaSellAmount,
    order: docOrder,
    businessCaseId,
  });
  try {
    await ensurePoolMirrorExecutionEigenbelegDocument({
      traderTrade: trade,
      traderExecutionDoc: sellDoc,
      executionType: 'sell',
    });
  } catch (_) {
    // Pool eigenbeleg must not block trader booking
  }
  const sellDocRef = resolveDocumentReference(sellDoc, { context: 'trade_sell_delta' });

  return bookSettlementEntry({
    userId: traderId,
    userRole: 'trader',
    entryType: 'trade_sell',
    amount: deltaSellAmount,
    tradeId: trade.id,
    tradeNumber,
    description: `Wertpapierverkauf Trade #${tradeNumber} (${trade.get('symbol') || ''})`,
    ...sellDocRef,
    businessCaseId,
  });
}

async function bookInvestorPartialRealizationDeltaIfAny({ trade, previousTrade }) {
  if (!trade || !previousTrade) return null;

  const poolCtx = await resolvePoolContextForTraderSell(trade);
  if (!poolCtx) return null;

  const { poolTrade, traderTrade, participations } = poolCtx;
  const businessCaseId = await ensureBusinessCaseIdForTrade(traderTrade);

  const currentSellQty = getTotalSellQuantity(traderTrade);
  const previousSellQty = getTotalSellQuantity(previousTrade);
  const deltaSellQty = round2(currentSellQty - previousSellQty);
  if (!Number.isFinite(deltaSellQty) || deltaSellQty <= 0) return null;

  const buyOrder = traderTrade.get('buyOrder') || {};
  const buyQuantity = Number(traderTrade.get('quantity') || buyOrder.quantity || 0);
  if (!Number.isFinite(buyQuantity) || buyQuantity <= 0) return null;

  const sellFraction = deltaSellQty / buyQuantity;
  const tradeNumber = poolTrade.get('tradeNumber') || traderTrade.get('tradeNumber');
  const commissionRate = await getTraderCommissionRate();
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const taxConfig = config.tax || {};
  const tradeBuyPrice = resolveTradeBuyPrice(poolTrade);
  const tradeSellPrice = resolveTradeSellPrice(traderTrade);

  const unsettled = participations.filter((p) => !p.get('isSettled'));
  if (!unsettled.length) return null;

  const prefetchedInvestments = await prefetchInvestmentsById(unsettled);
  const investorTaxProfileCache = new Map();

  const results = [];
  for (const participation of unsettled) {
    const participationInvestmentId = String(participation.get('investmentId') || '').trim();
    const prefetched = participationInvestmentId
      ? prefetchedInvestments.get(participationInvestmentId)
      : null;
    const investment = prefetched || await findInvestment(participation.get('investmentId'), participation, poolTrade);
    if (!investment) continue;

    const investmentNumber = String(investment.get('investmentNumber') || '').trim();

    const investorId = investment.get('investorId');
    if (!investorId) continue;
    const status = String(investment.get('status') || '');
    if (status === 'completed' || status === 'cancelled') continue;

    const rawOwnership = Number(participation.get('ownershipPercentage') || 0);
    const ownershipRatio = rawOwnership > 1 ? rawOwnership / 100 : rawOwnership;
    if (!Number.isFinite(ownershipRatio) || ownershipRatio <= 0) continue;

    const investmentCapital = Number(investment.get('amount') || investment.get('currentValue') || 0);
    const legDelta = computeInvestorPartialSellDelta({
      investmentCapital,
      tradeBuyPrice,
      tradeSellPrice,
      sellFraction,
      commissionRate,
      feeConfig,
    });
    if (!legDelta) continue;

    const {
      buyLeg,
      sellLeg,
      grossProfit: grossProfitDelta,
      commission: commissionDelta,
      netProfit: netProfitDelta,
      investorSellCashDelta,
    } = legDelta;

    let investorProfile = investorTaxProfileCache.get(investorId);
    if (investorProfile === undefined) {
      investorProfile = await resolveUserTaxProfile(investorId);
      investorTaxProfileCache.set(investorId, investorProfile || null);
    }
    const taxBreakdown = netProfitDelta > 0
      ? calculateWithholdingBundle({
          taxableAmount: netProfitDelta,
          taxConfig,
          userProfile: investorProfile,
        })
      : { withholdingTax: 0, solidaritySurcharge: 0, churchTax: 0, totalTax: 0 };

    const partialBill = await createCollectionBillDocument({
      investorId,
      investmentId: investment.id,
      trade: poolTrade,
      ownershipPercentage: round2(ownershipRatio * 100),
      grossProfit: grossProfitDelta,
      commission: commissionDelta,
      netProfit: netProfitDelta,
      commissionRate,
      investmentCapital,
      buyLeg,
      sellLeg,
      taxBreakdown,
      businessCaseId,
    });
    const partialBillRef = resolveDocumentReference(partialBill, { context: 'partial_sell_collection_bill' });

    const partialMeta = partialBill.get('metadata') || {};
    const partialTransfer = round2(partialMeta.transferAmount
      ?? Math.max(0, Math.abs(investorSellCashDelta) - Math.abs(commissionDelta)));
    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_return',
      amount: partialTransfer,
      tradeId: poolTrade.id,
      tradeNumber,
      investmentId: investment.id,
      investmentNumber,
      description: `Teil-Sell Abrechnung Trade #${tradeNumber} – Rückzahlung ${investmentNumber || investment.id}`,
      ...partialBillRef,
      businessCaseId,
    });

    if (commissionDelta > 0) {
      await bookSettlementEntry({
        userId: investorId,
        userRole: 'investor',
        entryType: 'commission_debit',
        amount: -Math.abs(commissionDelta),
        tradeId: poolTrade.id,
        tradeNumber,
        investmentId: investment.id,
        investmentNumber,
        description: `Teil-Sell Provision Trade #${tradeNumber} (${(commissionRate * 100).toFixed(0)}%)`,
        ...partialBillRef,
        businessCaseId,
      });
    }

    if (taxBreakdown.totalTax > 0) {
      await bookInvestorTaxEntries({
        investorId,
        investmentId: investment.id,
        investmentNumber,
        trade,
        tradeNumber,
        collectionBillId: partialBillRef.referenceDocumentId,
        collectionBillNumber: partialBillRef.referenceDocumentNumber,
        taxBreakdown,
        bookSettlementEntry,
        businessCaseId,
      });
    }

    results.push({
      investorId,
      investmentId: investment.id,
      deltaSellAmount: investorSellCashDelta,
      deltaGrossProfit: grossProfitDelta,
      deltaCommission: commissionDelta,
      deltaTax: taxBreakdown.totalTax || 0,
    });
  }

  return results;
}

module.exports = {
  bookTraderBuyEntryIfMissing,
  bookTraderSellDeltaIfAny,
  bookInvestorPartialRealizationDeltaIfAny,
};
