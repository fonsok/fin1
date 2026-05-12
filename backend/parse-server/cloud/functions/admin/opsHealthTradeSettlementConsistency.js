'use strict';

const { SETTLEMENT_EPSILON } = require('./opsHealthConstants');
const { round2, statementSumKey } = require('./opsHealthSettlementHelpers');
const {
  getStatementSumsByTypeForTrade,
  sumExpectedTaxFromCollectionBills,
  getExpectedTaxByInvestmentForTrade,
  getExpectedSettlementByInvestmentForTrade,
  getInvestmentsByIds,
} = require('./opsHealthSettlementQueries');

async function handleGetTradeSettlementConsistencyStatus(request) {
  const requestedLimit = Number(request.params?.limit || 50);
  const limit = Math.min(200, Math.max(1, requestedLimit));

  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.equalTo('status', 'completed');
  tradeQuery.descending('updatedAt');
  tradeQuery.limit(limit);
  const trades = await tradeQuery.find({ useMasterKey: true });

  let checkedTrades = 0;
  let checkedInvestments = 0;
  const mismatches = [];

  for (const trade of trades) {
    const tradeId = trade.id;
    const tradeNumber = trade.get('tradeNumber');
    const expectedTaxByInvestment = await getExpectedTaxByInvestmentForTrade(tradeId);
    const expectedSettlementByInvestment = await getExpectedSettlementByInvestmentForTrade(tradeId);
    const statementSumsByType = await getStatementSumsByTypeForTrade(tradeId);

    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.equalTo('tradeId', tradeId);
    const participations = await participationQuery.find({ useMasterKey: true });
    if (!participations.length) continue;
    const investmentsById = await getInvestmentsByIds(participations.map((p) => p.get('investmentId')));

    checkedTrades += 1;
    for (const participation of participations) {
      const investmentId = String(participation.get('investmentId') || '').trim();
      if (!investmentId) continue;

      const investment = investmentsById.get(investmentId) || null;
      if (!investment) continue;

      const investorId = String(investment.get('investorId') || '').trim();
      if (!investorId) continue;

      const allocatedAmount = Number(participation.get('allocatedAmount') || 0);
      const profitShare = Number(participation.get('profitShare') || 0);
      const commissionAmount = Number(participation.get('commissionAmount') || 0);
      const expectedByDoc = expectedSettlementByInvestment.get(`${investorId}::${investmentId}`) || null;
      const expectedCommission = expectedByDoc
        ? round2(Math.max(0, expectedByDoc.commission))
        : round2(Math.max(0, commissionAmount));
      const expectedGrossReturnByDocOrParticipation = expectedByDoc
        ? round2(Math.max(0, expectedByDoc.grossReturn))
        : round2(Math.max(0, allocatedAmount + profitShare));
      const rawInvestmentAmount = investment.get('amount');
      const rawInvestmentProfit = investment.get('profit');
      const investmentAmount = Number(rawInvestmentAmount || 0);
      const investmentProfit = Number(rawInvestmentProfit || 0);
      const investmentCommission = Number(investment.get('totalCommissionPaid') || expectedCommission);
      const expectedGrossReturnByInvestment = round2(investmentAmount + investmentProfit + investmentCommission);
      const hasInvestmentGrossReturnSignal = rawInvestmentAmount !== undefined || rawInvestmentProfit !== undefined;
      const expectedGrossReturn = hasInvestmentGrossReturnSignal && expectedGrossReturnByInvestment > 0
        ? expectedGrossReturnByInvestment
        : expectedGrossReturnByDocOrParticipation;

      const actualGrossReturn = statementSumsByType.get(statementSumKey({
        userId: investorId,
        investmentId,
        entryType: 'investment_return',
      })) || 0;
      const actualCommission = statementSumsByType.get(statementSumKey({
        userId: investorId,
        investmentId,
        entryType: 'commission_debit',
      })) || 0;
      const actualWithholding = statementSumsByType.get(statementSumKey({
        userId: investorId,
        investmentId,
        entryType: 'withholding_tax_debit',
      })) || 0;
      const actualSolidarity = statementSumsByType.get(statementSumKey({
        userId: investorId,
        investmentId,
        entryType: 'solidarity_surcharge_debit',
      })) || 0;
      const actualChurch = statementSumsByType.get(statementSumKey({
        userId: investorId,
        investmentId,
        entryType: 'church_tax_debit',
      })) || 0;
      const actualTaxTotal = round2(actualWithholding + actualSolidarity + actualChurch);
      const expectedTaxTotal = expectedTaxByInvestment.get(`${investorId}::${investmentId}`)
        ?? await sumExpectedTaxFromCollectionBills({ userId: investorId, tradeId, investmentId });

      checkedInvestments += 1;
      const returnDiff = round2(actualGrossReturn - expectedGrossReturn);
      const commissionDiff = round2(actualCommission - expectedCommission);
      const taxDiff = round2(actualTaxTotal - expectedTaxTotal);
      const hasMismatch =
        Math.abs(returnDiff) > SETTLEMENT_EPSILON ||
        Math.abs(commissionDiff) > SETTLEMENT_EPSILON ||
        Math.abs(taxDiff) > SETTLEMENT_EPSILON;

      if (hasMismatch) {
        mismatches.push({
          tradeId,
          tradeNumber,
          investmentId,
          investorId,
          expected: {
            grossReturn: expectedGrossReturn,
            commission: expectedCommission,
            taxTotal: expectedTaxTotal,
          },
          actual: {
            grossReturn: actualGrossReturn,
            commission: actualCommission,
            taxTotal: actualTaxTotal,
          },
          diff: {
            grossReturn: returnDiff,
            commission: commissionDiff,
            taxTotal: taxDiff,
          },
        });
      }
    }
  }

  const mismatchCount = mismatches.length;
  const overall = mismatchCount === 0 ? 'healthy' : 'degraded';

  return {
    overall,
    checkedTrades,
    checkedInvestments,
    mismatchCount,
    epsilon: SETTLEMENT_EPSILON,
    mismatchSamples: mismatches.slice(0, 50),
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleGetTradeSettlementConsistencyStatus,
};
