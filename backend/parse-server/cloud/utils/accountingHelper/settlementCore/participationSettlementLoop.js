'use strict';

const { audit } = require('../../structuredLogger');
const { settleParticipation } = require('../settlementParticipationProcessor');

async function settleAllParticipations({
  participations,
  poolSettlementTrade,
  trade,
  traderId,
  settlementTradeNumber,
  netTradingProfitForPool,
  commissionRates,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
  businessCaseId,
}) {
  let totalCommission = 0;
  let totalTraderCommission = 0;
  let totalAppCommission = 0;
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
        commissionRates,
        feeConfig,
        tradeBuyPrice,
        tradeSellPrice,
        taxConfig,
      });
      if (result) {
        totalCommission += result.commission;
        totalTraderCommission += result.traderCommission ?? result.commission;
        totalAppCommission += result.appCommission ?? 0;
        investorBreakdown.push({
          investorId: result.investorId,
          investmentId: result.investmentId,
          grossProfit: result.grossProfit,
          commission: result.traderCommission ?? result.commission,
          taxWithheld: result.taxWithheld,
        });
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

  return {
    totalCommission,
    totalTraderCommission,
    totalAppCommission,
    investorBreakdown,
  };
}

module.exports = {
  settleAllParticipations,
};
