'use strict';

const { requirePermission, requireStatusChangePermission, logPermissionCheck } = require('../../utils/permissions');

Parse.Cloud.define('searchUsers', async (request) => {
  requirePermission(request, 'searchUsers');

  const { query: searchQuery, role, status, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query(Parse.User);

  if (searchQuery) {
    const emailQuery = new Parse.Query(Parse.User);
    emailQuery.contains('email', searchQuery.toLowerCase());
    const idQuery = new Parse.Query(Parse.User);
    idQuery.contains('customerId', searchQuery.toUpperCase());
    query._orQuery([emailQuery, idQuery]);
  }

  if (role) query.equalTo('role', role);
  if (status) query.equalTo('status', status);

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const users = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    users: users.map(u => ({
      objectId: u.id,
      customerId: u.get('customerId'),
      email: u.get('email'),
      username: u.get('username') || u.get('email'),
      firstName: u.get('firstName'),
      lastName: u.get('lastName'),
      role: u.get('role'),
      status: u.get('status'),
      kycStatus: u.get('kycStatus'),
      createdAt: u.get('createdAt'),
      updatedAt: u.get('updatedAt'),
      lastLoginAt: u.get('lastLoginAt')
    })),
    total
  };
});

Parse.Cloud.define('getUserDetails', async (request) => {
  requirePermission(request, 'getUserDetails');

  const { userId } = request.params;
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  await logPermissionCheck(request, 'getUserDetails', 'User', userId);

  const profileQuery = new Parse.Query('UserProfile');
  profileQuery.equalTo('userId', userId);
  const profile = await profileQuery.first({ useMasterKey: true });

  const addressQuery = new Parse.Query('UserAddress');
  addressQuery.equalTo('userId', userId);
  addressQuery.equalTo('isPrimary', true);
  const address = await addressQuery.first({ useMasterKey: true });

  const walletQuery = new Parse.Query('Wallet');
  walletQuery.equalTo('userId', userId);
  const wallet = await walletQuery.first({ useMasterKey: true });

  const role = user.get('role');
  let trades = [];
  let tradeSummary = null;
  if (role === 'trader') {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', `user:${user.get('email')}`);
    tradeQuery.descending('createdAt');
    tradeQuery.limit(10);
    trades = await tradeQuery.find({ useMasterKey: true });

    const allTradesQuery = new Parse.Query('Trade');
    allTradesQuery.equalTo('traderId', `user:${user.get('email')}`);
    const allTrades = await allTradesQuery.find({ useMasterKey: true });
    const completedTrades = allTrades.filter(t => t.get('status') === 'completed');
    const totalProfit = completedTrades.reduce((sum, t) => sum + (t.get('grossProfit') || 0), 0);
    const totalCommission = completedTrades.reduce((sum, t) => sum + (t.get('totalFees') || 0), 0);

    tradeSummary = {
      totalTrades: allTrades.length,
      completedTrades: completedTrades.length,
      activeTrades: allTrades.filter(t => ['pending', 'active', 'partial'].includes(t.get('status'))).length,
      totalProfit,
      totalCommission,
    };
  }

  let investments = [];
  let investmentSummary = null;
  if (role === 'investor') {
    const investmentQuery = new Parse.Query('Investment');
    investmentQuery.equalTo('investorId', userId);
    investmentQuery.descending('createdAt');
    investmentQuery.limit(10);
    investments = await investmentQuery.find({ useMasterKey: true });

    const allInvestmentsQuery = new Parse.Query('Investment');
    allInvestmentsQuery.equalTo('investorId', userId);
    const allInvestments = await allInvestmentsQuery.find({ useMasterKey: true });
    const totalInvested = allInvestments.reduce((sum, i) => sum + (i.get('amount') || 0), 0);
    const totalProfit = allInvestments.reduce((sum, i) => sum + (i.get('profit') || 0), 0);
    const activeInvestments = allInvestments.filter(i => i.get('status') === 'active');

    investmentSummary = {
      totalInvestments: allInvestments.length,
      activeInvestments: activeInvestments.length,
      totalInvested,
      totalProfit,
      currentValue: activeInvestments.reduce((sum, i) => sum + (i.get('currentValue') || i.get('amount') || 0), 0),
    };
  }

  const activityQuery = new Parse.Query('AuditLog');
  activityQuery.equalTo('resourceId', userId);
  activityQuery.descending('createdAt');
  activityQuery.limit(10);
  const activities = await activityQuery.find({ useMasterKey: true });

  const formatDate = (date) => {
    if (!date) return null;
    if (date instanceof Date) return date.toISOString();
    if (date.iso) return date.iso;
    return date;
  };

  const tradesWithInvestors = await Promise.all(trades.map(async (t) => {
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
        } catch (e) {}
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

  return {
    user: {
      objectId: user.id,
      customerId: user.get('customerId'),
      email: user.get('email'),
      username: user.get('username') || user.get('email'),
      firstName: user.get('firstName'),
      lastName: user.get('lastName'),
      role: user.get('role'),
      status: user.get('status'),
      statusReason: user.get('statusReason'),
      kycStatus: user.get('kycStatus'),
      onboardingCompleted: user.get('onboardingCompleted'),
      createdAt: formatDate(user.createdAt),
      updatedAt: formatDate(user.updatedAt),
      lastLoginAt: formatDate(user.get('lastLoginAt')),
    },
    profile: profile ? profile.toJSON() : null,
    address: address ? address.toJSON() : null,
    wallet: wallet ? {
      balance: wallet.get('balance') || 0,
      currency: wallet.get('currency') || 'EUR',
      lastUpdated: formatDate(wallet.get('updatedAt')),
    } : null,
    tradeSummary,
    trades: tradesWithInvestors,
    investmentSummary,
    investments: investments.map(i => ({
      objectId: i.id,
      traderId: i.get('traderId'),
      amount: i.get('amount'),
      status: i.get('status'),
      profit: i.get('profit'),
      createdAt: formatDate(i.get('createdAt')),
    })),
    recentActivity: activities.map(a => ({
      action: a.get('action'),
      description: a.get('description') || a.get('action'),
      createdAt: formatDate(a.get('createdAt')),
    })),
  };
});

Parse.Cloud.define('updateUserStatus', async (request) => {
  const { userId, status, reason } = request.params;

  if (!userId || !status) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and status required');
  }

  requireStatusChangePermission(request, status);

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  const oldStatus = user.get('status');
  user.set('status', status);
  user.set('statusReason', reason);
  user.set('statusChangedAt', new Date());
  user.set('statusChangedBy', request.user.id);

  await user.save(null, { useMasterKey: true });

  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', 'update_user_status');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('oldValues', { status: oldStatus });
  log.set('newValues', { status, reason });
  log.set('metadata', {
    performedBy: request.user.id,
    performedByRole: request.user.get('role'),
  });
  await log.save(null, { useMasterKey: true });

  return { success: true, oldStatus, newStatus: status };
});
