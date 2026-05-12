'use strict';

const { logPermissionCheck } = require('../../utils/permissions');
const { readCustomerNumber } = require('../../utils/userIdentity');
const { formatAdminUserDate } = require('./usersDetailFormat');
const { loadAccountStatementAndWalletControls } = require('./usersDetailStatementsAndWallet');
const { loadTraderTradeLists, enrichTradesWithInvestors } = require('./usersDetailTrader');
const { loadInvestorInvestmentLists, mapInvestmentsForAdminDetail } = require('./usersDetailInvestor');

async function handleGetUserDetails(request) {
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

  const formatDate = formatAdminUserDate;

  const { trades, tradeSummary } = await loadTraderTradeLists(user);
  const { investments, investmentSummary } = await loadInvestorInvestmentLists(user, userId);

  const activityQuery = new Parse.Query('AuditLog');
  activityQuery.equalTo('resourceId', userId);
  activityQuery.descending('createdAt');
  activityQuery.limit(10);
  const activities = await activityQuery.find({ useMasterKey: true });

  const {
    accountStatement,
    walletControls,
    userWalletActionModeOverride,
  } = await loadAccountStatementAndWalletControls(user, formatDate);

  const tradesWithInvestors = await enrichTradesWithInvestors(trades, formatDate);

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
      walletActionModeOverride: userWalletActionModeOverride,
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
    walletControls,
    tradeSummary,
    trades: tradesWithInvestors,
    investmentSummary,
    investments: await mapInvestmentsForAdminDetail(investments, formatDate),
    accountStatement,
    recentActivity: activities.map(a => ({
      action: a.get('action'),
      description: a.get('description') || a.get('action'),
      createdAt: formatDate(a.get('createdAt')),
    })),
  };
}

module.exports = {
  handleGetUserDetails,
};
