'use strict';

const { getTraderCommissionRate, loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { bookAccountStatementEntry, bookSettlementEntry } = require('./statements');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('./taxation');
const { createCollectionBillDocument, createTradeExecutionDocument } = require('./documents');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  getTotalSellAmount,
  getTotalSellQuantity,
  getRepresentativeSellOrder,
} = require('./settlementTradeMath');
const { findExistingStatementEntry, prefetchInvestmentsById } = require('./settlementQueries');
const { findInvestment } = require('./settlementInvestmentFallback');
const { bookInvestorTaxEntries } = require('./settlementTaxEntries');

async function bookTraderBuyEntryIfMissing(trade) {
  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const buyOrder = trade.get('buyOrder') || {};
  const buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);

  if (!traderId || !trade.id || !Number.isFinite(buyAmount) || buyAmount <= 0) {
    return null;
  }

  const existing = await findExistingStatementEntry({
    userId: traderId,
    tradeId: trade.id,
    entryType: 'trade_buy',
  });
  if (existing) return existing;

  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const buyDoc = await createTradeExecutionDocument({
    traderId,
    trade,
    executionType: 'buy',
    amount: buyAmount,
    order: buyOrder,
    businessCaseId,
  });
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
  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const currentSellAmount = getTotalSellAmount(trade);
  const previousSellAmount = getTotalSellAmount(previousTrade);
  const deltaSellAmount = round2(currentSellAmount - previousSellAmount);

  if (!traderId || !trade.id || !Number.isFinite(deltaSellAmount) || deltaSellAmount <= 0) {
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
  const tradeId = trade.id;
  if (!tradeId) return null;

  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const currentSellAmount = getTotalSellAmount(trade);
  const previousSellAmount = getTotalSellAmount(previousTrade);
  const deltaSellAmount = round2(currentSellAmount - previousSellAmount);
  if (!Number.isFinite(deltaSellAmount) || deltaSellAmount <= 0) return null;

  const currentSellQty = getTotalSellQuantity(trade);
  const previousSellQty = getTotalSellQuantity(previousTrade);
  const deltaSellQty = round2(currentSellQty - previousSellQty);
  if (!Number.isFinite(deltaSellQty) || deltaSellQty <= 0) return null;

  const buyOrder = trade.get('buyOrder') || {};
  const buyQuantity = Number(trade.get('quantity') || buyOrder.quantity || 0);
  if (!Number.isFinite(buyQuantity) || buyQuantity <= 0) return null;

  const tradeNumber = trade.get('tradeNumber');
  const commissionRate = await getTraderCommissionRate();
  const config = await loadConfig();
  const taxConfig = config.tax || {};

  const participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .equalTo('isSettled', false)
    .find({ useMasterKey: true });
  if (!participations.length) return null;
  const prefetchedInvestments = await prefetchInvestmentsById(participations);
  const investorTaxProfileCache = new Map();

  const results = [];
  for (const participation of participations) {
    const participationInvestmentId = String(participation.get('investmentId') || '').trim();
    const prefetched = participationInvestmentId
      ? prefetchedInvestments.get(participationInvestmentId)
      : null;
    const investment = prefetched || await findInvestment(participation.get('investmentId'), participation, trade);
    if (!investment) continue;

    const investmentNumber = String(investment.get('investmentNumber') || '').trim();

    const investorId = investment.get('investorId');
    if (!investorId) continue;
    const status = String(investment.get('status') || '');
    if (status === 'completed' || status === 'cancelled') continue;

    const rawOwnership = Number(participation.get('ownershipPercentage') || 0);
    const ownershipRatio = rawOwnership > 1 ? rawOwnership / 100 : rawOwnership;
    if (!Number.isFinite(ownershipRatio) || ownershipRatio <= 0) continue;

    const allocatedAmount = Number(participation.get('allocatedAmount') || investment.get('amount') || 0);
    const investorSellCashDelta = round2(deltaSellAmount * ownershipRatio);
    const investorCostDelta = round2(allocatedAmount * (deltaSellQty / buyQuantity));
    const grossProfitDelta = round2(investorSellCashDelta - investorCostDelta);
    const commissionDelta = grossProfitDelta > 0 ? round2(grossProfitDelta * commissionRate) : 0;
    const netProfitDelta = round2(grossProfitDelta - commissionDelta);

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
      trade,
      ownershipPercentage: round2(ownershipRatio * 100),
      grossProfit: grossProfitDelta,
      commission: commissionDelta,
      netProfit: netProfitDelta,
      commissionRate,
      investmentCapital: investorCostDelta,
      buyLeg: { amount: investorCostDelta, fees: { totalFees: 0 } },
      sellLeg: { amount: investorSellCashDelta, fees: { totalFees: 0 } },
      taxBreakdown,
      businessCaseId,
    });
    const partialBillRef = resolveDocumentReference(partialBill, { context: 'partial_sell_collection_bill' });

    await bookAccountStatementEntry({
      userId: investorId,
      entryType: 'investment_return',
      amount: Math.abs(investorSellCashDelta),
      tradeId: trade.id,
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
        tradeId: trade.id,
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
