'use strict';

const { getTraderCommissionRate, loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { bookSettlementEntry } = require('./statements');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('./taxation');
const { createCreditNoteDocument } = require('./documents');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const { isPairedTraderLegTrade, getMirrorTradeForPairedTraderLeg } = require('../pairedTradeMirrorSync');
const { computeTradingFeesWithBreakdown } = require('./settlementTradeMath');
const { ensureParticipationsForTrade } = require('./settlementInvestmentFallback');
const { bookTraderTaxEntries } = require('./settlementTaxEntries');
const { settleParticipation } = require('./settlementParticipationProcessor');
const { bookTraderTradeLifecycleEntries } = require('./settlementTraderLifecycleBooks');

async function settleAndDistribute(trade) {
  const traderId = trade.get('traderId');
  const tradeNumber = trade.get('tradeNumber');
  const rawGrossProfit = trade.get('grossProfit') || 0;
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const { totalFees: totalTradingFees, breakdown: tradingFeeBreakdown } =
    computeTradingFeesWithBreakdown(trade);
  const netTradingProfit = round2(rawGrossProfit - totalTradingFees);

  await bookTraderTradeLifecycleEntries({
    trade,
    traderId,
    tradeNumber,
    totalTradingFees,
    tradingFeeBreakdown,
    businessCaseId,
  });

  // Do not return early when gross/net trading profit is zero or negative.
  // Otherwise `settleParticipation` never runs, `Investment` rows stay `active`,
  // and the investor app keeps showing them under active investments after a completed sell.

  const existingTraderCommissionEntry = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', trade.id)
    .equalTo('entryType', 'commission_credit')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  const existingCreditNote = await new Parse.Query('Document')
    .equalTo('type', 'traderCreditNote')
    .equalTo('tradeId', trade.id)
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  const traderCreditAlreadyBooked = Boolean(existingTraderCommissionEntry || existingCreditNote);
  const commissionRate = await getTraderCommissionRate();
  const config = await loadConfig();
  const feeConfig = config.financial;
  const taxConfig = config.tax || {};
  const traderProfile = await resolveUserTaxProfile(traderId);

  let participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', trade.id)
    .find({ useMasterKey: true });

  /** Participations + economics for investor pool settlement (mirror leg for executePairedBuy). */
  let poolSettlementTrade = trade;
  let netTradingProfitForPool = netTradingProfit;
  let settlementTradeNumber = tradeNumber;

  if (participations.length === 0) {
    const skipPoolFallback = await isPairedTraderLegTrade(trade);
    if (skipPoolFallback) {
      const mirrorTrade = await getMirrorTradeForPairedTraderLeg(trade);
      if (mirrorTrade) {
        participations = await new Parse.Query('PoolTradeParticipation')
          .equalTo('tradeId', mirrorTrade.id)
          .find({ useMasterKey: true });
        if (participations.length > 0) {
          poolSettlementTrade = mirrorTrade;
          settlementTradeNumber = mirrorTrade.get('tradeNumber') || tradeNumber;
          const mirrorGross = Number(mirrorTrade.get('grossProfit') || 0);
          const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(mirrorTrade);
          netTradingProfitForPool = round2(mirrorGross - mirrorFees);
        }
      }
    } else {
      participations = await ensureParticipationsForTrade(trade);
    }
  }
  if (participations.length === 0) return null;

  const buyOrderForPrice = poolSettlementTrade.get('buyOrder') || {};
  const sellOrdersForPrice = poolSettlementTrade.get('sellOrders') || [];
  const firstSellOrderForPrice = sellOrdersForPrice[0] || poolSettlementTrade.get('sellOrder') || {};
  const tradeBuyPrice = poolSettlementTrade.get('entryPrice') || poolSettlementTrade.get('buyPrice') || buyOrderForPrice.price || 0;
  const tradeSellPrice = poolSettlementTrade.get('exitPrice') || poolSettlementTrade.get('sellPrice') || firstSellOrderForPrice.price || firstSellOrderForPrice.limitPrice || 0;

  let totalCommission = 0;
  const investorBreakdown = [];
  for (const participation of participations) {
    const result = await settleParticipation({
      participation,
      trade: poolSettlementTrade,
      traderId,
      tradeNumber: settlementTradeNumber,
      netTradingProfit: netTradingProfitForPool,
      commissionRate,
      feeConfig,
      tradeBuyPrice,
      tradeSellPrice,
      taxConfig,
    });
    if (result) {
      totalCommission += result.commission;
      investorBreakdown.push(result);
    }
  }

  const totalInvestorGrossProfit = investorBreakdown.reduce(
    (sum, b) => sum + (Number.isFinite(b.grossProfit) ? b.grossProfit : 0),
    0,
  );
  const creditNoteGrossProfit = totalInvestorGrossProfit > 0 ? totalInvestorGrossProfit : netTradingProfit;

  if (totalCommission > 0 && !traderCreditAlreadyBooked) {
    const traderTaxBreakdown = calculateWithholdingBundle({
      taxableAmount: totalCommission,
      taxConfig,
      userProfile: traderProfile,
    });
    const creditNote = await createCreditNoteDocument({
      traderId,
      trade,
      totalCommission: round2(totalCommission),
      commissionRate,
      grossProfit: round2(creditNoteGrossProfit),
      netProfit: round2(creditNoteGrossProfit - totalCommission),
      investorBreakdown,
      taxBreakdown: traderTaxBreakdown,
      businessCaseId,
    });
    const creditNoteRef = resolveDocumentReference(creditNote, { context: 'commission_credit' });

    await bookSettlementEntry({
      userId: traderId,
      userRole: 'trader',
      entryType: 'commission_credit',
      amount: round2(totalCommission),
      tradeId: trade.id,
      tradeNumber,
      description: `Provisionsgutschrift Trade #${tradeNumber}`,
      ...creditNoteRef,
      businessCaseId,
    });

    if (traderTaxBreakdown.totalTax > 0) {
      await bookTraderTaxEntries({
        traderId,
        trade,
        tradeNumber,
        creditNoteId: creditNoteRef.referenceDocumentId,
        creditNoteNumber: creditNoteRef.referenceDocumentNumber,
        taxBreakdown: traderTaxBreakdown,
        bookSettlementEntry,
        businessCaseId,
      });
    }
  }

  return {
    tradeId: trade.id,
    tradeNumber,
    rawGrossProfit: round2(rawGrossProfit),
    tradingFees: round2(totalTradingFees),
    netTradingProfit: round2(netTradingProfit),
    mirrorGrossProfit: round2(totalInvestorGrossProfit),
    totalCommission: round2(totalCommission),
    netProfit: round2(creditNoteGrossProfit - totalCommission),
    traderTaxWithheld: round2(
      calculateWithholdingBundle({
        taxableAmount: totalCommission,
        taxConfig,
        userProfile: traderProfile,
      }).totalTax
    ),
    commissionRate,
    investorCount: investorBreakdown.length,
  };
}

module.exports = {
  settleAndDistribute,
};
