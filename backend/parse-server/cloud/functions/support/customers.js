'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { readCustomerNumber, resolveEndUserObjectId } = require('../../utils/userIdentity');

function requireEndUserObjectId(params) {
  const id = resolveEndUserObjectId(params);
  if (!id) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY,
      'userId required (Parse _User.objectId). customerId is accepted as a legacy alias only.');
  }
  return id;
}

// CSR PORTAL - CUSTOMER SEARCH
// ============================================================================

/**
 * Search customers by name, email, Parse objectId, or business customerNumber (ANL-/TRD-).
 */
Parse.Cloud.define('searchCustomers', async (request) => {
  requireAdminRole(request);

  const { query: searchQuery } = request.params;
  if (!searchQuery || searchQuery.length < 2) {
    return { results: [] };
  }

  const searchLower = searchQuery.toLowerCase();

  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('role', ['investor', 'trader', 'user']);
  userQuery.limit(50);

  const users = await userQuery.find({ useMasterKey: true });

  const results = users
    .filter((user) => {
      const email = (user.get('email') || '').toLowerCase();
      const firstName = (user.get('firstName') || '').toLowerCase();
      const lastName = (user.get('lastName') || '').toLowerCase();
      const fullName = `${firstName} ${lastName}`.toLowerCase();
      const objectId = user.id.toLowerCase();
      const biz = (readCustomerNumber(user) || '').toLowerCase();

      return (
        email.includes(searchLower) ||
        firstName.includes(searchLower) ||
        lastName.includes(searchLower) ||
        fullName.includes(searchLower) ||
        objectId.includes(searchLower) ||
        biz.includes(searchLower)
      );
    })
    .map((user) => ({
      objectId: user.id,
      userId: user.id,
      customerNumber: readCustomerNumber(user),
      email: user.get('email'),
      firstName: user.get('firstName'),
      lastName: user.get('lastName'),
      fullName: `${user.get('firstName') || ''} ${user.get('lastName') || ''}`.trim() || user.get('email'),
      status: user.get('status') || 'active',
      role: user.get('role'),
      kycStatus: user.get('kycStatus') || 'pending',
    }));

  return { results };
});

/**
 * Get customer profile
 */
Parse.Cloud.define('getCustomerProfile', async (request) => {
  requireAdminRole(request);

  const userId = requireEndUserObjectId(request.params);

  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(userId, { useMasterKey: true });

  if (!user) {
    return null;
  }

  return {
    objectId: user.id,
    userId: user.id,
    customerNumber: readCustomerNumber(user),
    email: user.get('email'),
    firstName: user.get('firstName'),
    lastName: user.get('lastName'),
    fullName: `${user.get('firstName') || ''} ${user.get('lastName') || ''}`.trim() || user.get('email'),
    status: user.get('status') || 'active',
    role: user.get('role'),
    kycStatus: user.get('kycStatus') || 'pending',
    createdAt: user.get('createdAt'),
    lastLoginAt: user.get('lastLoginAt'),
  };
});

/**
 * Get customer KYC status
 */
Parse.Cloud.define('getCustomerKYCStatus', async (request) => {
  requireAdminRole(request);

  const userId = requireEndUserObjectId(request.params);

  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(userId, { useMasterKey: true });

  return {
    status: user.get('kycStatus') || 'pending',
    level: user.get('kycLevel') || 'basic',
    verifiedAt: user.get('kycVerifiedAt'),
    expiresAt: user.get('kycExpiresAt'),
    documents: [],
  };
});

/**
 * Get customer investments
 */
Parse.Cloud.define('getCustomerInvestments', async (request) => {
  requireAdminRole(request);

  const userId = resolveEndUserObjectId(request.params);
  if (!userId) {
    return { investments: [] };
  }

  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(userId, { useMasterKey: true });
  const userEmail = user.get('email');

  const possibleInvestorIds = [userId];

  if (userEmail) {
    possibleInvestorIds.push(`user:${userEmail.toLowerCase()}`);
  }

  const query = new Parse.Query('Investment');
  query.containedIn('investorId', possibleInvestorIds);
  query.descending('createdAt');
  query.limit(50);

  const investments = await query.find({ useMasterKey: true });

  return {
    investments: investments.map((inv) => ({
      objectId: inv.id,
      investorId: inv.get('investorId'),
      investorName: inv.get('investorName'),
      traderId: inv.get('traderId'),
      traderName: inv.get('traderName') || 'Unknown Trader',
      amount: inv.get('amount') || 0,
      currentValue: inv.get('currentValue') || inv.get('amount') || 0,
      status: inv.get('status') || 'active',
      performance: inv.get('performance') || 0,
      investedAt: inv.get('createdAt'),
      createdAt: inv.get('createdAt'),
      updatedAt: inv.get('updatedAt'),
      completedAt: inv.get('completedAt'),
    })),
  };
});

/**
 * Get customer trades
 */
Parse.Cloud.define('getCustomerTrades', async (request) => {
  requireAdminRole(request);

  const userId = resolveEndUserObjectId(request.params);
  if (!userId) {
    return { trades: [] };
  }

  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(userId, { useMasterKey: true });
  const role = user.get('role');
  const userEmail = user.get('email');

  let trades = [];

  if (role === 'trader') {
    const possibleTraderIds = [userId];

    if (userEmail) {
      possibleTraderIds.push(`user:${userEmail.toLowerCase()}`);
    }

    const query = new Parse.Query('Trade');
    query.containedIn('traderId', possibleTraderIds);
    query.descending('createdAt');
    query.limit(50);
    trades = await query.find({ useMasterKey: true });
  } else if (role === 'investor') {
    const possibleInvestorIds = [userId];
    if (userEmail) {
      possibleInvestorIds.push(`user:${userEmail.toLowerCase()}`);
    }

    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.containedIn('investorId', possibleInvestorIds);
    const participations = await participationQuery.find({ useMasterKey: true });

    const tradeIds = [...new Set(participations.map(p => p.get('tradeId')))];

    if (tradeIds.length > 0) {
      const tradeQuery = new Parse.Query('Trade');
      tradeQuery.containedIn('objectId', tradeIds);
      tradeQuery.descending('createdAt');
      tradeQuery.limit(50);
      trades = await tradeQuery.find({ useMasterKey: true });
    }
  }

  return {
    trades: trades.map((trade) => {
      const buyOrder = trade.get('buyOrder') || {};
      const amount = buyOrder.totalAmount || trade.get('amount') || 0;

      return {
        objectId: trade.id,
        tradeNumber: trade.get('tradeNumber'),
        traderId: trade.get('traderId'),
        traderName: trade.get('traderName') || 'Unknown',
        symbol: trade.get('symbol'),
        description: trade.get('description'),
        tradeType: trade.get('tradeType') || 'unknown',
        amount: amount,
        executedAt: trade.get('executedAt') || trade.get('createdAt'),
        completedAt: trade.get('completedAt'),
        status: trade.get('status') || 'completed',
      };
    }),
  };
});

/**
 * Get customer documents
 */
Parse.Cloud.define('getCustomerDocuments', async (request) => {
  requireAdminRole(request);

  const userId = resolveEndUserObjectId(request.params);
  if (!userId) {
    return { documents: [] };
  }

  const query = new Parse.Query('UserDocument');
  query.equalTo('userId', userId);
  query.descending('createdAt');
  query.limit(50);

  const documents = await query.find({ useMasterKey: true });

  return {
    documents: documents.map((doc) => ({
      objectId: doc.id,
      documentType: doc.get('documentType') || 'unknown',
      fileName: doc.get('fileName') || 'document',
      uploadedAt: doc.get('createdAt'),
      status: doc.get('status') || 'pending',
    })),
  };
});
