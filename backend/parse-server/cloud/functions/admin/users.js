'use strict';

const { requirePermission, requireStatusChangePermission, logPermissionCheck } = require('../../utils/permissions');
const { applyQuerySort } = require('../../utils/applyQuerySort');
const { escapeRegExp } = require('../../utils/helpers');
const { readCustomerNumber } = require('../../utils/userIdentity');
const PROTECTED_ADMIN_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance'];
const DEACTIVATING_STATUSES = ['suspended', 'locked', 'inactive', 'disabled'];

Parse.Cloud.define('searchUsers', async (request) => {
  requirePermission(request, 'searchUsers');

  const { query: searchQuery, role, status, limit = 50, skip = 0 } = request.params;

  function buildUserListQuery() {
    let q;
    if (searchQuery) {
      const emailQuery = new Parse.Query(Parse.User);
      emailQuery.contains('email', searchQuery.toLowerCase());
      const bizNumQuery = new Parse.Query(Parse.User);
      bizNumQuery.contains('customerNumber', searchQuery.toUpperCase());
      const legacyBizQuery = new Parse.Query(Parse.User);
      legacyBizQuery.contains('customerId', searchQuery.toUpperCase());
      const idQuery = Parse.Query.or(bizNumQuery, legacyBizQuery);
      const firstNameQuery = new Parse.Query(Parse.User);
      firstNameQuery.matches('firstName', new RegExp(escapeRegExp(searchQuery), 'i'));
      const lastNameQuery = new Parse.Query(Parse.User);
      lastNameQuery.matches('lastName', new RegExp(escapeRegExp(searchQuery), 'i'));
      const usernameQuery = new Parse.Query(Parse.User);
      usernameQuery.contains('username', searchQuery.toLowerCase());
      q = Parse.Query.or(emailQuery, idQuery, firstNameQuery, lastNameQuery, usernameQuery);
    } else {
      q = new Parse.Query(Parse.User);
    }
    if (role) q.equalTo('role', role);
    if (status) q.equalTo('status', status);
    return q;
  }

  const query = buildUserListQuery();
  applyQuerySort(query, request.params || {}, {
    allowed: ['createdAt', 'updatedAt', 'email', 'lastName', 'firstName', 'lastLoginAt'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  query.limit(limit);
  query.skip(skip);

  const countQuery = buildUserListQuery();

  const users = await query.find({ useMasterKey: true });
  const total = await countQuery.count({ useMasterKey: true });

  return {
    users: users.map(u => ({
      objectId: u.id,
      customerNumber: readCustomerNumber(u),
      email: u.get('email'),
      username: u.get('username') || u.get('email'),
      firstName: u.get('firstName'),
      lastName: u.get('lastName'),
      role: u.get('role'),
      status: u.get('status'),
      kycStatus: u.get('kycStatus'),
      accountType: u.get('accountType') || 'individual',
      companyKybStatus: u.get('companyKybStatus') || null,
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
    const totalProfit = completedTrades.reduce((sum, t) => sum + (t.get('netProfit') || t.get('grossProfit') || 0), 0);

    // Sum investor commission from PoolTradeParticipation
    let totalCommission = 0;
    for (const ct of completedTrades) {
      const partQuery = new Parse.Query('PoolTradeParticipation');
      partQuery.equalTo('tradeId', ct.id);
      const parts = await partQuery.find({ useMasterKey: true });
      totalCommission += parts.reduce((s, p) => s + (p.get('commissionAmount') || 0), 0);
    }

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
    // iOS app stores investorId as "user:<email>" while Parse objectId is also possible
    const investorIdByEmail = `user:${user.get('email')}`;

    const invByIdQuery = new Parse.Query('Investment');
    invByIdQuery.equalTo('investorId', userId);
    const invByEmailQuery = new Parse.Query('Investment');
    invByEmailQuery.equalTo('investorId', investorIdByEmail);
    const investmentQuery = Parse.Query.or(invByIdQuery, invByEmailQuery);
    investmentQuery.descending('createdAt');
    investmentQuery.limit(10);
    investments = await investmentQuery.find({ useMasterKey: true });

    const allInvByIdQuery = new Parse.Query('Investment');
    allInvByIdQuery.equalTo('investorId', userId);
    const allInvByEmailQuery = new Parse.Query('Investment');
    allInvByEmailQuery.equalTo('investorId', investorIdByEmail);
    const allInvestmentsQuery = Parse.Query.or(allInvByIdQuery, allInvByEmailQuery);
    const allInvestments = await allInvestmentsQuery.find({ useMasterKey: true });
    const totalInvested = allInvestments.reduce((sum, i) => sum + (i.get('amount') || 0), 0);
    const totalProfit = allInvestments.reduce((sum, i) => sum + (i.get('profit') || 0), 0);
    const activeInvestments = allInvestments.filter(i => i.get('status') === 'active');

    const completedInvestments = allInvestments.filter(i => i.get('status') === 'completed');
    investmentSummary = {
      totalInvestments: allInvestments.length,
      activeInvestments: activeInvestments.length,
      completedInvestments: completedInvestments.length,
      reservedInvestments: allInvestments.filter(i => i.get('status') === 'reserved').length,
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

  // ── Account Statement (both roles) ──
  const userStableId = `user:${user.get('email')}`;
  const stmtQuery = new Parse.Query('AccountStatement');
  stmtQuery.equalTo('userId', userStableId);
  stmtQuery.ascending('createdAt');
  stmtQuery.limit(100);
  const stmtEntries = await stmtQuery.find({ useMasterKey: true });

  const { loadConfig } = require('../../utils/configHelper/index.js');
  const liveConfig = await loadConfig(true);
  const initialBalance =
    typeof liveConfig.financial?.initialAccountBalance === 'number'
      ? liveConfig.financial.initialAccountBalance
      : 0.0;

  let runningBalance = initialBalance;
  const accountStatementEntries = stmtEntries.map(e => {
    const amount = e.get('amount') || 0;
    runningBalance += amount;
    return {
      objectId: e.id,
      entryType: e.get('entryType'),
      amount,
      balanceAfter: parseFloat(runningBalance.toFixed(2)),
      tradeId: e.get('tradeId'),
      tradeNumber: e.get('tradeNumber'),
      investmentId: e.get('investmentId'),
      description: e.get('description'),
      referenceDocumentId: e.get('referenceDocumentId') || null,
      source: e.get('source'),
      createdAt: formatDate(e.get('createdAt')),
    };
  });

  const totalCredits = stmtEntries.reduce((s, e) => {
    const a = e.get('amount') || 0;
    return a > 0 ? s + a : s;
  }, 0);
  const totalDebits = stmtEntries.reduce((s, e) => {
    const a = e.get('amount') || 0;
    return a < 0 ? s + Math.abs(a) : s;
  }, 0);

  const accountStatement = {
    initialBalance,
    closingBalance: parseFloat(runningBalance.toFixed(2)),
    totalCredits: parseFloat(totalCredits.toFixed(2)),
    totalDebits: parseFloat(totalDebits.toFixed(2)),
    netChange: parseFloat((totalCredits - totalDebits).toFixed(2)),
    entries: accountStatementEntries,
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
      customerNumber: readCustomerNumber(user),
      email: user.get('email'),
      username: user.get('username') || user.get('email'),
      firstName: user.get('firstName'),
      lastName: user.get('lastName'),
      salutation: user.get('salutation'),
      phoneNumber: user.get('phoneNumber'),
      streetAndNumber: user.get('streetAndNumber'),
      postalCode: user.get('postalCode'),
      city: user.get('city'),
      state: user.get('state'),
      country: user.get('country'),
      dateOfBirth: user.get('dateOfBirth'),
      nationality: user.get('nationality'),
      role: user.get('role'),
      status: user.get('status'),
      statusReason: user.get('statusReason'),
      kycStatus: user.get('kycStatus'),
      accountType: user.get('accountType') || 'individual',
      onboardingCompleted: user.get('onboardingCompleted'),
      companyKybCompleted: user.get('companyKybCompleted') || false,
      companyKybStatus: user.get('companyKybStatus') || null,
      companyKybStep: user.get('companyKybStep') || null,
      companyKybCompletedAt: formatDate(user.get('companyKybCompletedAt')),
      companyKybReviewedAt: formatDate(user.get('companyKybReviewedAt')),
      companyKybReviewedBy: user.get('companyKybReviewedBy') || null,
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
    investments: await Promise.all(investments.map(async (i) => {
      // Find participation for this specific investment
      const partQuery = new Parse.Query('PoolTradeParticipation');
      partQuery.equalTo('investmentId', i.id);
      const participations = await partQuery.find({ useMasterKey: true });

      // Derive profit/status from settled participation if investment itself is stale
      let investProfit = i.get('profit') || 0;
      let investStatus = i.get('status') || 'reserved';
      let investProfitPct = i.get('profitPercentage') || 0;
      let investCommission = i.get('totalCommissionPaid') || 0;
      let investTradeCount = i.get('numberOfTrades') || 0;

      // Build trade info from participation (1 investment → 1 trade)
      let tradeNumber = null;
      let tradeSymbol = null;
      let tradeStatus = null;
      let tradeCompletedAt = null;
      let ownershipPct = 0;
      let allocatedAmount = 0;
      let docRef = null;

      for (const p of participations) {
        const isSettled = p.get('isSettled');
        ownershipPct = p.get('ownershipPercentage') || 0;
        allocatedAmount = p.get('allocatedAmount') || 0;

        if (isSettled && investProfit === 0) {
          investProfit = p.get('profitShare') || 0;
          investCommission = p.get('commissionAmount') || 0;
          investTradeCount = 1;
          investStatus = 'completed';
          const capital = i.get('amount') || allocatedAmount;
          if (capital > 0) {
            investProfitPct = parseFloat(((investProfit / capital) * 100).toFixed(2));
          }
        }

        const tradeId = p.get('tradeId');
        if (tradeId) {
          try {
            const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
            tradeNumber = trade.get('tradeNumber');
            tradeSymbol = trade.get('symbol');
            tradeStatus = trade.get('status');
            tradeCompletedAt = formatDate(trade.get('completedAt'));
          } catch (_) {}
        }
      }

      // Look up document reference (Beleg/Rechnung) from AccountStatement
      const docQuery = new Parse.Query('AccountStatement');
      docQuery.equalTo('investmentId', i.id);
      docQuery.containedIn('entryType', ['investment_profit', 'commission_debit']);
      docQuery.exists('referenceDocumentId');
      docQuery.limit(1);
      const docEntry = await docQuery.first({ useMasterKey: true });
      if (docEntry) {
        const refDocId = docEntry.get('referenceDocumentId');
        if (refDocId) {
          try {
            const doc = await new Parse.Query('Document').get(refDocId, { useMasterKey: true });
            docRef = doc.get('documentNumber') || refDocId;
          } catch (_) {
            docRef = refDocId;
          }
        }
      }

      return {
        objectId: i.id,
        traderId: i.get('traderId'),
        traderName: i.get('traderName'),
        amount: i.get('amount'),
        status: investStatus,
        profit: investProfit,
        currentValue: i.get('currentValue'),
        investmentNumber: i.get('investmentNumber'),
        serviceChargeAmount: i.get('serviceChargeAmount'),
        totalCommissionPaid: investCommission,
        numberOfTrades: investTradeCount,
        profitPercentage: investProfitPct,
        createdAt: formatDate(i.get('createdAt')),
        activatedAt: formatDate(i.get('activatedAt')),
        completedAt: formatDate(i.get('completedAt')),
        tradeNumber,
        tradeSymbol,
        tradeStatus,
        tradeCompletedAt,
        ownershipPercentage: ownershipPct,
        allocatedAmount,
        docRef,
      };
    })),
    accountStatement,
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
  const actorUserId = request.user && request.user.id;
  const targetRole = user.get('role');

  // Best practice guard: never allow self-lockout actions.
  if (actorUserId && actorUserId === userId && DEACTIVATING_STATUSES.includes(status)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Self-suspension is not allowed');
  }

  // Best practice guard: never deactivate the last active privileged admin.
  if (PROTECTED_ADMIN_ROLES.includes(targetRole) && DEACTIVATING_STATUSES.includes(status)) {
    const activeAdminQuery = new Parse.Query(Parse.User);
    activeAdminQuery.containedIn('role', PROTECTED_ADMIN_ROLES);
    activeAdminQuery.notContainedIn('status', DEACTIVATING_STATUSES);
    const activeAdminCount = await activeAdminQuery.count({ useMasterKey: true });
    if (activeAdminCount <= 1) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot suspend the last active admin');
    }
  }

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
