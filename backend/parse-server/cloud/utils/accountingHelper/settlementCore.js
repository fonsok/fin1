'use strict';

const { getTraderCommissionRate, loadConfig } = require('../configHelper/index.js');
const { round2, resolveTradeBuyPrice, resolveTradeSellPrice } = require('./shared');
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
const { resolveTraderSettlementBookingTrade } = require('../../services/poolMirrorActivation/traderCustomerBookingPolicy');
const { audit } = require('../structuredLogger');

async function settleAndDistribute(trade) {
  const traderId = trade.get('traderId');
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const {
    traderBookingTrade,
    poolSettlementTrade: initialPoolTrade,
    invokedOnMirrorLeg,
  } = await resolveTraderSettlementBookingTrade(trade);

  const lifecycleTrade = traderBookingTrade || trade;
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

  const existingTraderCommissionEntry = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', commissionTradeId)
    .equalTo('entryType', 'commission_credit')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  const existingCreditNote = await new Parse.Query('Document')
    .equalTo('type', 'traderCreditNote')
    .equalTo('tradeId', commissionTradeId)
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  const traderCreditAlreadyBooked = Boolean(existingTraderCommissionEntry || existingCreditNote);
  const commissionRate = await getTraderCommissionRate();
  const config = await loadConfig();
  const feeConfig = config.financial;
  const taxConfig = config.tax || {};
  const traderProfile = await resolveUserTaxProfile(traderId);

  let participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', initialPoolTrade.id)
    .find({ useMasterKey: true });

  let poolSettlementTrade = initialPoolTrade;
  let netTradingProfitForPool = netTradingProfit;
  let settlementTradeNumber = initialPoolTrade.get('tradeNumber') || lifecycleTradeNumber;

  if (participations.length === 0 && !invokedOnMirrorLeg) {
    const skipPoolFallback = await isPairedTraderLegTrade(trade);
    if (skipPoolFallback) {
      const mirrorTrade = await getMirrorTradeForPairedTraderLeg(trade);
      if (mirrorTrade) {
        participations = await new Parse.Query('PoolTradeParticipation')
          .equalTo('tradeId', mirrorTrade.id)
          .find({ useMasterKey: true });
        if (participations.length === 0) {
          participations = await ensureParticipationsForTrade(mirrorTrade);
        }
        if (participations.length > 0) {
          poolSettlementTrade = mirrorTrade;
          settlementTradeNumber = mirrorTrade.get('tradeNumber') || lifecycleTradeNumber;
          const mirrorGross = Number(mirrorTrade.get('grossProfit') || 0);
          const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(mirrorTrade);
          netTradingProfitForPool = round2(mirrorGross - mirrorFees);
        }
      }
    } else {
      participations = await ensureParticipationsForTrade(trade);
    }
  } else if (participations.length === 0 && invokedOnMirrorLeg) {
    participations = await ensureParticipationsForTrade(initialPoolTrade);
    if (participations.length > 0) {
      const mirrorGross = Number(initialPoolTrade.get('grossProfit') || 0);
      const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(initialPoolTrade);
      netTradingProfitForPool = round2(mirrorGross - mirrorFees);
    }
  } else if (invokedOnMirrorLeg) {
    const mirrorGross = Number(initialPoolTrade.get('grossProfit') || 0);
    const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(initialPoolTrade);
    netTradingProfitForPool = round2(mirrorGross - mirrorFees);
  }

  if (participations.length === 0) return null;

  const tradeBuyPrice = resolveTradeBuyPrice(poolSettlementTrade);
  const tradeSellPrice = resolveTradeSellPrice(poolSettlementTrade);

  let totalCommission = 0;
  const investorBreakdown = [];
  const failures = [];
  for (const participation of participations) {
    const participationId = participation.id;
    const investmentIdForLog = participation.get('investmentId') || null;
    try {
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
    } catch (err) {
      const msg = err && err.message ? err.message : String(err);
      failures.push({ participationId, investmentId: investmentIdForLog, error: msg });
      audit.error('settlement.participation.failure', {
        tradeId: trade.id,
        tradeNumber: trade.get('tradeNumber'),
        participationId,
        investmentId: investmentIdForLog || null,
        businessCaseId,
        error: msg,
        stack: err && err.stack ? err.stack : undefined,
        message: '❌ settleParticipation failed',
      });
    }
  }

  if (failures.length > 0) {
    const summary = failures
      .map((f) => `${f.participationId}(inv=${f.investmentId || 'n/a'}: ${f.error})`)
      .join('; ');
    throw new Error(
      `settleAndDistribute partial failure for Trade #${trade.get('tradeNumber')} (${trade.id}): `
      + `${failures.length}/${participations.length} investor participations failed — ${summary}`,
    );
  }

  const totalInvestorGrossProfit = investorBreakdown.reduce(
    (sum, b) => sum + (Number.isFinite(b.grossProfit) ? b.grossProfit : 0),
    0,
  );
  const creditNoteGrossProfit = totalInvestorGrossProfit > 0 ? totalInvestorGrossProfit : netTradingProfit;

  if (totalCommission > 0 && !traderCreditAlreadyBooked && traderBookingTrade) {
    const traderTaxBreakdown = calculateWithholdingBundle({
      taxableAmount: totalCommission,
      taxConfig,
      userProfile: traderProfile,
    });
    const creditNote = await createCreditNoteDocument({
      traderId,
      trade: traderBookingTrade,
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
      tradeId: traderBookingTrade.id,
      tradeNumber: commissionTradeNumber,
      description: `Provisionsgutschrift Trade #${commissionTradeNumber}`,
      ...creditNoteRef,
      businessCaseId,
    });

    if (traderTaxBreakdown.totalTax > 0) {
      await bookTraderTaxEntries({
        traderId,
        trade: traderBookingTrade,
        tradeNumber: commissionTradeNumber,
        creditNoteId: creditNoteRef.referenceDocumentId,
        creditNoteNumber: creditNoteRef.referenceDocumentNumber,
        taxBreakdown: traderTaxBreakdown,
        bookSettlementEntry,
        businessCaseId,
      });
    }
  }

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
