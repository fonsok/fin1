'use strict';

const { SETTLEMENT_EPSILON } = require('./opsHealthConstants');
const { round2, statementSumKey } = require('./opsHealthSettlementHelpers');

async function handleBenchmarkTradeSettlementConsistency(request) {
  const requestedLimit = Number(request.params?.limit || 200);
  const limit = Math.min(500, Math.max(1, requestedLimit));

  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.equalTo('status', 'completed');
  tradeQuery.descending('updatedAt');
  tradeQuery.limit(limit);
  const trades = await tradeQuery.find({ useMasterKey: true });

  let totalParticipations = 0;
  const perTrade = [];

  for (const trade of trades) {
    const tradeId = trade.id;
    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.equalTo('tradeId', tradeId);
    const participations = await participationQuery.find({ useMasterKey: true });
    const p = participations.length;
    totalParticipations += p;

    const estimatedQueriesBefore = 2 + (7 * p);
    const estimatedQueriesAfter = 4;
    perTrade.push({
      tradeId,
      tradeNumber: trade.get('tradeNumber'),
      participations: p,
      estimatedQueriesBefore,
      estimatedQueriesAfter,
      estimatedQueryReduction: Math.max(0, estimatedQueriesBefore - estimatedQueriesAfter),
    });
  }

  const estimatedBeforeTotal = perTrade.reduce((sum, row) => sum + row.estimatedQueriesBefore, 0);
  const estimatedAfterTotal = perTrade.reduce((sum, row) => sum + row.estimatedQueriesAfter, 0);
  const estimatedReduction = Math.max(0, estimatedBeforeTotal - estimatedAfterTotal);
  const estimatedReductionPercent = estimatedBeforeTotal > 0
    ? round2((estimatedReduction / estimatedBeforeTotal) * 100)
    : 0;

  const t0 = Date.now();
  const runtime = await Parse.Cloud.run('getTradeSettlementConsistencyStatus', { limit }, { useMasterKey: true });
  const durationMs = Date.now() - t0;

  return {
    checkedAt: new Date().toISOString(),
    limit,
    sampledCompletedTrades: trades.length,
    totalParticipations,
    estimatedBeforeTotal,
    estimatedAfterTotal,
    estimatedReduction,
    estimatedReductionPercent,
    runtime: {
      durationMs,
      overall: runtime?.overall || 'unknown',
      checkedTrades: Number(runtime?.checkedTrades || 0),
      checkedInvestments: Number(runtime?.checkedInvestments || 0),
      mismatchCount: Number(runtime?.mismatchCount || 0),
    },
    perTradeTop: perTrade
      .sort((a, b) => b.estimatedQueryReduction - a.estimatedQueryReduction)
      .slice(0, 25),
  };
}

function runSyntheticConsistencyWorkload({ trades, participationsPerTrade }) {
  const t0 = Date.now();
  const mismatchSamples = [];
  let checkedInvestments = 0;
  for (let t = 0; t < trades; t += 1) {
    const statementSumsByType = new Map();
    const expectedTaxByInvestment = new Map();
    for (let p = 0; p < participationsPerTrade; p += 1) {
      const investorId = `investor-${p % 200}`;
      const investmentId = `inv-${t}-${p}`;
      const grossReturn = round2(1000 + (p % 7) * 3.11);
      const commission = round2(12 + (p % 5) * 0.37);
      const tax = round2(3 + (p % 3) * 0.21);
      expectedTaxByInvestment.set(`${investorId}::${investmentId}`, tax);
      statementSumsByType.set(statementSumKey({ userId: investorId, investmentId, entryType: 'investment_return' }), grossReturn);
      statementSumsByType.set(statementSumKey({ userId: investorId, investmentId, entryType: 'commission_debit' }), commission);
      statementSumsByType.set(statementSumKey({ userId: investorId, investmentId, entryType: 'withholding_tax_debit' }), tax);

      const actualGrossReturn = statementSumsByType.get(statementSumKey({ userId: investorId, investmentId, entryType: 'investment_return' })) || 0;
      const actualCommission = statementSumsByType.get(statementSumKey({ userId: investorId, investmentId, entryType: 'commission_debit' })) || 0;
      const actualTax = statementSumsByType.get(statementSumKey({ userId: investorId, investmentId, entryType: 'withholding_tax_debit' })) || 0;
      const expectedTax = expectedTaxByInvestment.get(`${investorId}::${investmentId}`) || 0;

      if (
        Math.abs(actualGrossReturn - grossReturn) > SETTLEMENT_EPSILON ||
        Math.abs(actualCommission - commission) > SETTLEMENT_EPSILON ||
        Math.abs(actualTax - expectedTax) > SETTLEMENT_EPSILON
      ) {
        mismatchSamples.push({ t, p, investorId, investmentId });
      }
      checkedInvestments += 1;
    }
  }
  return {
    durationMs: Date.now() - t0,
    checkedInvestments,
    mismatches: mismatchSamples.length,
  };
}

async function handleBenchmarkTradeSettlementConsistencySynthetic(request) {
  const scenarios = Array.isArray(request.params?.scenarios) && request.params.scenarios.length > 0
    ? request.params.scenarios
    : [
      { trades: 20, participationsPerTrade: 100 },
      { trades: 20, participationsPerTrade: 500 },
    ];

  const results = [];
  for (const scenario of scenarios) {
    const trades = Math.max(1, Number(scenario.trades || 20));
    const participationsPerTrade = Math.max(1, Number(scenario.participationsPerTrade || 100));
    const totalParticipations = trades * participationsPerTrade;
    const estimatedBeforeTotal = trades * (2 + (7 * participationsPerTrade));
    const estimatedAfterTotal = trades * 4;
    const estimatedReduction = Math.max(0, estimatedBeforeTotal - estimatedAfterTotal);
    const estimatedReductionPercent = estimatedBeforeTotal > 0
      ? round2((estimatedReduction / estimatedBeforeTotal) * 100)
      : 0;
    const runtime = runSyntheticConsistencyWorkload({ trades, participationsPerTrade });

    results.push({
      trades,
      participationsPerTrade,
      totalParticipations,
      estimatedBeforeTotal,
      estimatedAfterTotal,
      estimatedReduction,
      estimatedReductionPercent,
      runtime,
    });
  }

  return {
    checkedAt: new Date().toISOString(),
    benchmarkType: 'synthetic',
    results,
  };
}

module.exports = {
  handleBenchmarkTradeSettlementConsistency,
  handleBenchmarkTradeSettlementConsistencySynthetic,
};
