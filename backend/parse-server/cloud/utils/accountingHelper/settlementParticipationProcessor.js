'use strict';

const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { findInvestment } = require('./settlementInvestmentFallback');
const { trySettleFromExistingBill } = require('./settlementParticipationBackfill');
const { settleNewParticipation } = require('./settlementParticipationPosting');
const { mergeInvestorFeeConfig } = require('./feeConfigSnapshot');

async function settleParticipation({
  participation,
  trade,
  traderId,
  tradeNumber,
  netTradingProfit,
  commissionRates,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
}) {
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);
  const rawOwnership = participation.get('ownershipPercentage') || 0;
  const ownershipRatio = rawOwnership > 1 ? rawOwnership / 100 : rawOwnership;
  const totalCommissionRate = commissionRates.totalRate;

  const proportionalProfitShare = round2(netTradingProfit * ownershipRatio);
  const proportionalCommission = round2(proportionalProfitShare * totalCommissionRate);
  const proportionalNetProfit = round2(proportionalProfitShare - proportionalCommission);

  const rawInvestmentId = participation.get('investmentId');
  const investment = await findInvestment(rawInvestmentId, participation, trade);
  if (!investment) {
    throw new Error(
      `GoB fail-closed: Investment not found for participation ${participation.id} (investmentId=${rawInvestmentId || 'n/a'})`
    );
  }

  const investorId = investment.get('investorId');
  const investmentCapital = investment.get('amount') || 0;
  console.log(`  📊 Found investment ${investment.id} for investor ${investorId}, capital=€${investmentCapital}`);

  const feeConfigForInvestor = mergeInvestorFeeConfig(investment, trade, feeConfig);

  const existingResult = await trySettleFromExistingBill({
    participation,
    investment,
    traderId,
    trade,
    tradeNumber,
    commissionRates,
    feeConfig: feeConfigForInvestor,
    tradeBuyPrice,
  });
  if (existingResult) return existingResult;

  return settleNewParticipation({
    participation,
    investment,
    trade,
    traderId,
    tradeNumber,
    commissionRates,
    feeConfig: feeConfigForInvestor,
    tradeBuyPrice,
    tradeSellPrice,
    taxConfig,
    proportionalProfitShare,
    proportionalCommission,
    proportionalNetProfit,
    rawOwnership,
    ownershipRatio,
    businessCaseId,
  });
}

module.exports = {
  settleParticipation,
};
