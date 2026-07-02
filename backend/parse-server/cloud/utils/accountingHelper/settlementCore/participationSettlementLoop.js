'use strict';

const { audit } = require('../../structuredLogger');
const { createCommissionRateResolver } = require('../../configHelper/index.js');
const { settleParticipation } = require('../settlementParticipationProcessor');
const { readSettlementParticipationBatchSize } = require('../../../services/poolMirrorActivation/poolMirrorScaleLimits');

async function settleParticipationSafe({
  participation,
  poolSettlementTrade,
  traderId,
  settlementTradeNumber,
  netTradingProfitForPool,
  commissionRateResolver,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
}) {
  const participationId = participation.id;
  const investmentIdForLog = participation.get('investmentId') || null;
  try {
    const result = await settleParticipation({
      participation,
      trade: poolSettlementTrade,
      traderId,
      tradeNumber: settlementTradeNumber,
      netTradingProfit: netTradingProfitForPool,
      commissionRateResolver,
      feeConfig,
      tradeBuyPrice,
      tradeSellPrice,
      taxConfig,
    });
    return { ok: true, result, participationId, investmentId: investmentIdForLog };
  } catch (err) {
    const msg = err && err.message ? err.message : String(err);
    return { ok: false, error: msg, participationId, investmentId: investmentIdForLog };
  }
}

function collectBreakdownFromResult(result, investorBreakdown, totals) {
  if (!result) return;
  totals.totalCommission += result.commission;
  totals.totalTraderCommission += result.traderCommission ?? result.commission;
  totals.totalAppCommission += result.appCommission ?? 0;
  investorBreakdown.push({
    investorId: result.investorId,
    investorName: result.investorName || null,
    investmentId: result.investmentId,
    grossProfit: result.grossProfit,
    commission: result.traderCommission ?? result.commission,
    taxWithheld: result.taxWithheld,
  });
}

async function settleAllParticipations({
  participations,
  poolSettlementTrade,
  trade,
  traderId,
  settlementTradeNumber,
  netTradingProfitForPool,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
  businessCaseId,
}) {
  const batchSize = readSettlementParticipationBatchSize();
  const commissionRateResolver = await createCommissionRateResolver();
  const totals = {
    totalCommission: 0,
    totalTraderCommission: 0,
    totalAppCommission: 0,
  };
  const investorBreakdown = [];
  const failures = [];

  for (let offset = 0; offset < participations.length; offset += batchSize) {
    const batch = participations.slice(offset, offset + batchSize);
    // eslint-disable-next-line no-await-in-loop
    const batchOutcomes = await Promise.all(batch.map((participation) => settleParticipationSafe({
      participation,
      poolSettlementTrade,
      traderId,
      settlementTradeNumber,
      netTradingProfitForPool,
      commissionRateResolver,
      feeConfig,
      tradeBuyPrice,
      tradeSellPrice,
      taxConfig,
    })));

    for (const outcome of batchOutcomes) {
      if (outcome.ok) {
        collectBreakdownFromResult(outcome.result, investorBreakdown, totals);
        continue;
      }
      failures.push({
        participationId: outcome.participationId,
        investmentId: outcome.investmentId,
        error: outcome.error,
      });
      audit.error('settlement.participation.failure', {
        tradeId: trade.id,
        tradeNumber: trade.get('tradeNumber'),
        participationId: outcome.participationId,
        investmentId: outcome.investmentId || null,
        businessCaseId,
        error: outcome.error,
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

  if (participations.length > batchSize) {
    audit.info('settlement.participation.batched', {
      tradeId: trade.id,
      tradeNumber: trade.get('tradeNumber'),
      investorCount: participations.length,
      batchSize,
      batchCount: Math.ceil(participations.length / batchSize),
      message: 'Pool participation settlement completed in batches',
    });
  }

  return {
    totalCommission: totals.totalCommission,
    totalTraderCommission: totals.totalTraderCommission,
    totalAppCommission: totals.totalAppCommission,
    investorBreakdown,
  };
}

module.exports = {
  settleAllParticipations,
  settleParticipationSafe,
};
