'use strict';

async function handleGetTestUserDetails(request) {
  const { userId } = request.params;
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const role = user.get('role');

  let trades = [];
  let tradeSummary = null;
  if (role === 'trader') {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', `user:${user.get('email')}`);
    tradeQuery.descending('createdAt');
    tradeQuery.limit(10);
    const rawTrades = await tradeQuery.find({ useMasterKey: true });

    trades = await Promise.all(rawTrades.map(async (t) => {
      const participationQuery = new Parse.Query('PoolTradeParticipation');
      participationQuery.equalTo('tradeId', t.id);
      const participations = await participationQuery.find({ useMasterKey: true });

      const createdAt = t.get('createdAt');
      const completedAt = t.get('completedAt');
      return {
        objectId: t.id,
        tradeNumber: t.get('tradeNumber'),
        symbol: t.get('symbol'),
        description: t.get('description'),
        status: t.get('status'),
        grossProfit: t.get('grossProfit'),
        totalFees: t.get('totalFees'),
        createdAt: createdAt instanceof Date ? createdAt.toISOString() : createdAt,
        completedAt: completedAt instanceof Date ? completedAt.toISOString() : completedAt,
        investors: participations.map(p => ({
          investorId: p.get('investorId'),
          investorName: p.get('investorName'),
          ownershipPercentage: p.get('ownershipPercentage'),
          investedAmount: p.get('allocatedAmount'),
          profitShare: p.get('profitShare'),
          isSettled: p.get('isSettled')
        }))
      };
    }));

    const completedTrades = rawTrades.filter(t => t.get('status') === 'completed');
    tradeSummary = {
      totalTrades: rawTrades.length,
      completedTrades: completedTrades.length,
      activeTrades: rawTrades.filter(t => ['pending', 'active', 'partial'].includes(t.get('status'))).length,
      totalProfit: completedTrades.reduce((sum, t) => sum + (t.get('grossProfit') || 0), 0),
      totalCommission: completedTrades.reduce((sum, t) => sum + (t.get('totalFees') || 0), 0),
    };
  }

  const userCreatedAt = user.get('createdAt');
  return {
    user: {
      objectId: user.id,
      email: user.get('email'),
      username: user.get('username'),
      role: user.get('role'),
      status: user.get('status') || 'active',
      createdAt: userCreatedAt instanceof Date ? userCreatedAt.toISOString() : userCreatedAt,
    },
    tradeSummary,
    trades,
  };
}

module.exports = {
  handleGetTestUserDetails,
};
