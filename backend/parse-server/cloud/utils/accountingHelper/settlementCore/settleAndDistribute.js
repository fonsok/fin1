'use strict';

const { round2 } = require('../shared');
const { ensureBusinessCaseIdForTrade } = require('../businessCaseId');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('../taxation');
const { resolveTraderSettlementBookingTrade } = require('../../../services/poolMirrorActivation/traderCustomerBookingPolicy');
const { computeTradingFeesWithBreakdown } = require('../settlementTradeMath');
const { bookTraderTradeLifecycleEntries } = require('../settlementTraderLifecycleBooks');
const { preparePoolSettlementScope } = require('./poolSettlementScope');
const { settleAllParticipations } = require('./participationSettlementLoop');
const {
  loadTraderCommissionIdempotency,
  bookTraderCommissionCreditIfDue,
} = require('./traderCommissionCredit');

async function settleAndDistribute(trade) {
  const traderId = trade.get('traderId');
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const {
    traderBookingTrade,
    poolSettlementTrade: initialPoolTrade,
    invokedOnMirrorLeg,
  } = await resolveTraderSettlementBookingTrade(trade);

  const lifecycleTrade = traderBookingTrade || trade;
  const lifecycleTradeStatus = String(lifecycleTrade.get('status') || '');
  if (lifecycleTradeStatus !== 'completed') {
    throw new Error(
      `GoB fail-closed: settleAndDistribute requires completed trader leg `
      + `(tradeId=${lifecycleTrade.id}, status=${lifecycleTradeStatus || 'n/a'})`,
    );
  }

  const lifecycleTradeNumber = lifecycleTrade.get('tradeNumber');
  const rawGrossProfit = lifecycleTrade.get('grossProfit') || 0;

  const { totalFees: totalTradingFees, breakdown: tradingFeeBreakdown } =
    computeTradingFeesWithBreakdown(lifecycleTrade);
  const netTradingProfit = round2(rawGrossProfit - totalTradingFees);

  if (!invokedOnMirrorLeg && traderBookingTrade) {
    await bookTraderTradeLifecycleEntries({
      trade: traderBookingTrade,
      traderId,
      tradeNumber: lifecycleTradeNumber,
      totalTradingFees,
      tradingFeeBreakdown,
      businessCaseId,
    });
  }

  const commissionTradeId = traderBookingTrade?.id || trade.id;
  const commissionTradeNumber = traderBookingTrade?.get('tradeNumber') ?? trade.get('tradeNumber');
  const traderCreditAlreadyBooked = await loadTraderCommissionIdempotency(commissionTradeId);

  const poolScope = await preparePoolSettlementScope({
    trade,
    traderBookingTrade,
    initialPoolTrade,
    invokedOnMirrorLeg,
    lifecycleTradeNumber,
    netTradingProfit,
  });

  if (!poolScope) return null;

  const {
    participations,
    poolSettlementTrade,
    settlementTradeNumber,
    netTradingProfitForPool,
    tradeBuyPrice,
    tradeSellPrice,
    commissionRate,
    feeConfig,
    taxConfig,
  } = poolScope;

  const { totalCommission, investorBreakdown } = await settleAllParticipations({
    participations,
    poolSettlementTrade,
    trade,
    traderId,
    settlementTradeNumber,
    netTradingProfitForPool,
    commissionRate,
    feeConfig,
    tradeBuyPrice,
    tradeSellPrice,
    taxConfig,
    businessCaseId,
  });

  const totalInvestorGrossProfit = investorBreakdown.reduce(
    (sum, b) => sum + (Number.isFinite(b.grossProfit) ? b.grossProfit : 0),
    0,
  );
  const creditNoteGrossProfit = totalInvestorGrossProfit > 0 ? totalInvestorGrossProfit : netTradingProfit;

  const commissionResult = await bookTraderCommissionCreditIfDue({
    totalCommission,
    traderCreditAlreadyBooked,
    traderBookingTrade,
    lifecycleTradeStatus,
    traderId,
    commissionTradeNumber,
    creditNoteGrossProfit,
    netTradingProfit,
    investorBreakdown,
    businessCaseId,
  });

  const commissionRateForSummary = commissionResult?.commissionRate ?? commissionRate;
  const taxConfigForSummary = commissionResult?.taxConfig ?? taxConfig;
  const traderProfileForSummary = commissionResult?.traderProfile
    ?? await resolveUserTaxProfile(traderId);

  return {
    tradeId: traderBookingTrade?.id || trade.id,
    tradeNumber: commissionTradeNumber,
    poolTradeId: poolSettlementTrade.id,
    rawGrossProfit: round2(rawGrossProfit),
    tradingFees: round2(totalTradingFees),
    netTradingProfit: round2(netTradingProfit),
    mirrorGrossProfit: round2(totalInvestorGrossProfit),
    totalCommission: round2(totalCommission),
    netProfit: round2(creditNoteGrossProfit - totalCommission),
    traderTaxWithheld: round2(
      calculateWithholdingBundle({
        taxableAmount: totalCommission,
        taxConfig: taxConfigForSummary,
        userProfile: traderProfileForSummary,
      }).totalTax,
    ),
    commissionRate: commissionRateForSummary,
    investorCount: investorBreakdown.length,
  };
}

module.exports = {
  settleAndDistribute,
};
