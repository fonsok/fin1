'use strict';

async function loadTraderTradeLists(user) {
  const role = user.get('role');
  if (role !== 'trader') {
    return { trades: [], tradeSummary: null };
  }

  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.equalTo('traderId', `user:${user.get('email')}`);
  tradeQuery.descending('createdAt');
  tradeQuery.limit(10);
  const trades = await tradeQuery.find({ useMasterKey: true });

  const allTradesQuery = new Parse.Query('Trade');
  allTradesQuery.equalTo('traderId', `user:${user.get('email')}`);
  const allTrades = await allTradesQuery.find({ useMasterKey: true });
  const completedTrades = allTrades.filter(t => t.get('status') === 'completed');
  const totalProfit = completedTrades.reduce((sum, t) => sum + (t.get('netProfit') || t.get('grossProfit') || 0), 0);

  let totalCommission = 0;
  for (const ct of completedTrades) {
    const partQuery = new Parse.Query('PoolTradeParticipation');
    partQuery.equalTo('tradeId', ct.id);
    const parts = await partQuery.find({ useMasterKey: true });
    totalCommission += parts.reduce((s, p) => s + (p.get('commissionAmount') || 0), 0);
  }

  const tradeSummary = {
    totalTrades: allTrades.length,
    completedTrades: completedTrades.length,
    activeTrades: allTrades.filter(t => ['pending', 'active', 'partial'].includes(t.get('status'))).length,
    totalProfit,
    totalCommission,
  };

  return { trades, tradeSummary };
}

async function enrichTradesWithInvestors(trades, formatDate) {
  return Promise.all(trades.map(async (t) => {
    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.equalTo('tradeId', t.id);
    const participations = await participationQuery.find({ useMasterKey: true });

    const investors = await Promise.all(participations.map(async (p) => {
      const investmentId = p.get('investmentId');
      let investorEmail = p.get('investorId');
      let investorName = p.get('investorName');

      if (!investorName && investmentId) {
        try {
          const investment = await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
          const investorId = investment.get('investorId');
          if (investorId) {
            const investor = await new Parse.Query(Parse.User).get(investorId, { useMasterKey: true });
            investorEmail = investor.get('email');
            investorName = investor.get('firstName')
              ? `${investor.get('firstName')} ${investor.get('lastName') || ''}`.trim()
              : investor.get('email');
          }
        } catch (e) {
          void e;
        }
      }

      if (investorEmail && investorEmail.startsWith('user:')) {
        investorEmail = investorEmail.replace('user:', '');
      }

      return {
        investmentId,
        investorId: p.get('investorId'),
        investorEmail,
        investorName: investorName || investorEmail || 'Unknown',
        ownershipPercentage: p.get('ownershipPercentage'),
        investedAmount: p.get('allocatedAmount') || p.get('investedAmount'),
        profitShare: p.get('profitShare'),
        commissionAmount: p.get('commissionAmount'),
        isSettled: p.get('isSettled'),
      };
    }));

    return {
      objectId: t.id,
      tradeNumber: t.get('tradeNumber'),
      symbol: t.get('symbol'),
      description: t.get('description'),
      status: t.get('status'),
      grossProfit: t.get('grossProfit') || 0,
      netProfit: t.get('netProfit') || 0,
      totalFees: t.get('totalFees') || 0,
      createdAt: formatDate(t.get('createdAt')),
      completedAt: formatDate(t.get('completedAt')),
      investors: investors.filter(i => i.investorName),
    };
  }));
}

module.exports = {
  loadTraderTradeLists,
  enrichTradesWithInvestors,
};
