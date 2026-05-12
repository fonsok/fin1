'use strict';

const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { findInvestment } = require('./settlementInvestmentFallback');
const { trySettleFromExistingBill } = require('./settlementParticipationBackfill');
const { settleNewParticipation } = require('./settlementParticipationPosting');

async function settleParticipation({
  participation,
  trade,
  traderId,
  tradeNumber,
  netTradingProfit,
  commissionRate,
  feeConfig,
  tradeBuyPrice,
  tradeSellPrice,
  taxConfig,
}) {
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);
  const rawOwnership = participation.get('ownershipPercentage') || 0;
  const ownershipRatio = rawOwnership > 1 ? rawOwnership / 100 : rawOwnership;

  const proportionalProfitShare = round2(netTradingProfit * ownershipRatio);
  const proportionalCommission = round2(proportionalProfitShare * commissionRate);
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

  const existingResult = await trySettleFromExistingBill({
    participation,
    investment,
    traderId,
    trade,
    tradeNumber,
    commissionRate,
    feeConfig,
    tradeBuyPrice,
  });
  if (existingResult) return existingResult;

  return settleNewParticipation({
    participation,
    investment,
    trade,
    traderId,
    tradeNumber,
    commissionRate,
    feeConfig,
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
