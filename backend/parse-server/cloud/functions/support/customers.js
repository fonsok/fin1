'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

// CSR PORTAL - CUSTOMER SEARCH
// ============================================================================

/**
 * Search customers by name, email, or ID
 * Available to: customer_service, admin, compliance
 */
Parse.Cloud.define('searchCustomers', async (request) => {
  requireAdminRole(request);

  const { query: searchQuery } = request.params;
  if (!searchQuery || searchQuery.length < 2) {
    return { results: [] };
  }

  const searchLower = searchQuery.toLowerCase();

  // Search in _User class for customers (investors and traders)
  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('role', ['investor', 'trader', 'user']);
  userQuery.limit(50);

  const users = await userQuery.find({ useMasterKey: true });

  // Filter by search term (name, email, or ID)
  const results = users
    .filter((user) => {
      const email = (user.get('email') || '').toLowerCase();
      const firstName = (user.get('firstName') || '').toLowerCase();
      const lastName = (user.get('lastName') || '').toLowerCase();
      const fullName = `${firstName} ${lastName}`.toLowerCase();
      const objectId = user.id.toLowerCase();

      return (
        email.includes(searchLower) ||
        firstName.includes(searchLower) ||
        lastName.includes(searchLower) ||
        fullName.includes(searchLower) ||
        objectId.includes(searchLower)
      );
    })
    .map((user) => ({
      objectId: user.id,
      customerId: user.id,
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
 * Available to: customer_service, admin, compliance
 */
Parse.Cloud.define('getCustomerProfile', async (request) => {
  requireAdminRole(request);

  const { customerId } = request.params;
  if (!customerId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'customerId required');
  }

  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(customerId, { useMasterKey: true });

  if (!user) {
    return null;
  }

  return {
    objectId: user.id,
    customerId: user.id,
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

  const { customerId } = request.params;
  if (!customerId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'customerId required');
  }

  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(customerId, { useMasterKey: true });

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
 * Queries investments by investorId (iOS app saves with investor.id which can be Parse User objectId or "user:email" format)
 */
Parse.Cloud.define('getCustomerInvestments', async (request) => {
  requireAdminRole(request);

  const { customerId } = request.params;
  if (!customerId) {
    return { investments: [] };
  }

  // Get user to check if they're an investor
  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(customerId, { useMasterKey: true });
  const userEmail = user.get('email');

  // Try multiple ID formats that iOS app might use
  const possibleInvestorIds = [customerId]; // Parse User objectId

  // Add email format if available (iOS test users use "user:email" format)
  if (userEmail) {
    possibleInvestorIds.push(`user:${userEmail.toLowerCase()}`);
  }

  console.log(`🔍 getCustomerInvestments: Searching for investorId in formats: ${possibleInvestorIds.join(', ')}`);

  // Query by all possible investorId formats
  const query = new Parse.Query('Investment');
  query.containedIn('investorId', possibleInvestorIds);
  query.descending('createdAt');
  query.limit(50);

  const investments = await query.find({ useMasterKey: true });

  console.log(`✅ getCustomerInvestments: Found ${investments.length} investments`);

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
 * For traders: returns trades they executed (traderId can be Parse User objectId or "user:email" format)
 * For investors: returns trades they're invested in via pool participations
 */
Parse.Cloud.define('getCustomerTrades', async (request) => {
  requireAdminRole(request);

  const { customerId } = request.params;
  if (!customerId) {
    return { trades: [] };
  }

  // Get user to determine role
  const userQuery = new Parse.Query(Parse.User);
  const user = await userQuery.get(customerId, { useMasterKey: true });
  const role = user.get('role');
  const userEmail = user.get('email');

  let trades = [];

  if (role === 'trader') {
    // For traders: try multiple ID formats that iOS app might use
    const possibleTraderIds = [customerId]; // Parse User objectId

    // Add email format if available (iOS test users use "user:email" format)
    if (userEmail) {
      possibleTraderIds.push(`user:${userEmail.toLowerCase()}`);
    }

    console.log(`🔍 getCustomerTrades (trader): Searching for traderId in formats: ${possibleTraderIds.join(', ')}`);

    // Query trades by all possible traderId formats
    const query = new Parse.Query('Trade');
    query.containedIn('traderId', possibleTraderIds);
    query.descending('createdAt');
    query.limit(50);
    trades = await query.find({ useMasterKey: true });

    console.log(`✅ getCustomerTrades (trader): Found ${trades.length} trades`);
  } else if (role === 'investor') {
    // For investors: find trades through pool participations
    // Try multiple investorId formats
    const possibleInvestorIds = [customerId];
    if (userEmail) {
      possibleInvestorIds.push(`user:${userEmail.toLowerCase()}`);
    }

    console.log(`🔍 getCustomerTrades (investor): Searching for investorId in formats: ${possibleInvestorIds.join(', ')}`);

    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.containedIn('investorId', possibleInvestorIds);
    const participations = await participationQuery.find({ useMasterKey: true });

    console.log(`✅ getCustomerTrades (investor): Found ${participations.length} participations`);

    // Get unique trade IDs from participations
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
      // Extract amount from buyOrder if available (iOS format)
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

  const { customerId } = request.params;
  if (!customerId) {
    return { documents: [] };
  }

  const query = new Parse.Query('UserDocument');
  query.equalTo('userId', customerId);
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

