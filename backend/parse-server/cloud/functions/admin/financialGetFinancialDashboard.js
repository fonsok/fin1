'use strict';

const { getTraderCommissionRate } = require('../../utils/configHelper/index.js');
const { totalRevenueFromTrades, totalFeesFromTrades } = require('./financialTradeAggregates');

async function handleGetFinancialDashboard() {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const investmentQuery = new Parse.Query('Investment');
  investmentQuery.containedIn('status', ['active', 'completed']);
  const investments = await investmentQuery.find({ useMasterKey: true });
  const totalInvestments = investments.reduce((sum, inv) => sum + (inv.get('amount') || 0), 0);

  const tradeQuery = new Parse.Query('Trade');
  const trades = await tradeQuery.find({ useMasterKey: true });

  console.log(`📊 getFinancialDashboard: Found ${trades.length} total trades`);

  const commissionRate = await getTraderCommissionRate();
  const totalRevenue = totalRevenueFromTrades(trades);
  const totalFees = totalFeesFromTrades(trades, commissionRate);

  const monthlyTradeQuery = new Parse.Query('Trade');
  monthlyTradeQuery.greaterThanOrEqualTo('createdAt', startOfMonth);
  const monthlyTrades = await monthlyTradeQuery.find({ useMasterKey: true });

  console.log(`📊 getFinancialDashboard: Found ${monthlyTrades.length} trades this month`);

  const monthlyRevenue = totalRevenueFromTrades(monthlyTrades);
  const monthlyFees = totalFeesFromTrades(monthlyTrades, commissionRate);

  const correctionQuery = new Parse.Query('FourEyesRequest');
  correctionQuery.equalTo('requestType', 'correction');
  correctionQuery.equalTo('status', 'pending');
  const pendingCorrections = await correctionQuery.count({ useMasterKey: true });

  const roundingQuery = new Parse.Query('RoundingDifference');
  roundingQuery.equalTo('status', 'open');
  const openRoundingDiffs = await roundingQuery.count({ useMasterKey: true });

  return {
    stats: {
      totalRevenue,
      totalFees,
      totalInvestments,
      pendingCorrections,
      openRoundingDiffs,
      monthlyRevenue,
      monthlyFees,
    },
  };
}

module.exports = {
  handleGetFinancialDashboard,
};
