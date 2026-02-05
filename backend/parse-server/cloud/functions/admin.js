// ============================================================================
// Parse Cloud Code
// functions/admin.js - Admin Functions
// ============================================================================
//
// Admin-Funktionen mit rollenbasierter Zugriffskontrolle.
// Dokumentation: Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md
//
// Rollen-Hierarchie:
//   - admin:            Voll-Admin auf App-Ebene
//   - business_admin:   Financial/Accounting (CFO, Finance)
//   - security_officer: Security & Release Gatekeeper (CISO)
//   - compliance:       Audit/Regulatory (Compliance Officer)
//   - customer_service: User-Support (CSR Team)
//
// WICHTIG: Parse Dashboard ist SEPARAT und gehört nur dem Server-Admin!
//
// ============================================================================

'use strict';

const {
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
  logPermissionCheck,
  getFinancialRoles,
  getSecurityRoles,
  isElevatedRole,
} = require('../utils/permissions');

// ============================================================================
// DASHBOARD STATS
// ============================================================================

/**
 * Get admin dashboard statistics.
 * Available to: admin, customer_service (limited), compliance
 */
Parse.Cloud.define('getAdminDashboard', async (request) => {
  requirePermission(request, 'getAdminDashboard');

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const role = request.user.get('role');

  // Basic stats for all admin roles
  const totalUsers = await new Parse.Query(Parse.User)
    .equalTo('status', 'active')
    .count({ useMasterKey: true });
  const newUsersToday = await new Parse.Query(Parse.User)
    .greaterThanOrEqualTo('createdAt', today)
    .count({ useMasterKey: true });

  // Support tickets (visible to all admin roles)
  const openTickets = await new Parse.Query('SupportTicket')
    .containedIn('status', ['open', 'in_progress'])
    .count({ useMasterKey: true });

  // Base response
  const response = {
    users: { total: totalUsers, newToday: newUsersToday },
    support: { openTickets },
  };

  // Extended stats only for admin and compliance
  if (role === 'admin' || role === 'compliance') {
    // Investments
    const activeInvestments = await new Parse.Query('Investment')
      .equalTo('status', 'active')
      .count({ useMasterKey: true });

    const invQuery = new Parse.Query('Investment');
    invQuery.equalTo('status', 'active');
    const investments = await invQuery.find({ useMasterKey: true });
    let totalInvested = 0;
    investments.forEach(i => totalInvested += i.get('amount') || 0);

    // Trades
    const openTrades = await new Parse.Query('Trade')
      .containedIn('status', ['active', 'partial'])
      .count({ useMasterKey: true });

    // Compliance
    const pendingReviews = await new Parse.Query('ComplianceEvent')
      .equalTo('requiresReview', true)
      .equalTo('reviewed', false)
      .count({ useMasterKey: true });

    // Pending approvals
    const pendingApprovals = await new Parse.Query('FourEyesRequest')
      .equalTo('status', 'pending')
      .count({ useMasterKey: true });

    response.investments = { active: activeInvestments, totalAmount: totalInvested };
    response.trading = { openTrades };
    response.compliance = { pendingReviews, pendingApprovals };
  }

  return response;
});

// ============================================================================
// USER MANAGEMENT
// ============================================================================

/**
 * Search users.
 * Available to: admin, customer_service, compliance
 */
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
      objectId: u.id,  // Parse convention: use objectId
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

/**
 * Get detailed user information.
 * Available to: admin, customer_service, compliance
 */
Parse.Cloud.define('getUserDetails', async (request) => {
  requirePermission(request, 'getUserDetails');

  const { userId } = request.params;
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  // Log access for audit trail
  await logPermissionCheck(request, 'getUserDetails', 'User', userId);

  // Get profile
  const profileQuery = new Parse.Query('UserProfile');
  profileQuery.equalTo('userId', userId);
  const profile = await profileQuery.first({ useMasterKey: true });

  // Get address
  const addressQuery = new Parse.Query('UserAddress');
  addressQuery.equalTo('userId', userId);
  addressQuery.equalTo('isPrimary', true);
  const address = await addressQuery.first({ useMasterKey: true });

  // Get wallet/cash balance
  const walletQuery = new Parse.Query('Wallet');
  walletQuery.equalTo('userId', userId);
  const wallet = await walletQuery.first({ useMasterKey: true });

  // Get trades (for traders)
  const role = user.get('role');
  let trades = [];
  let tradeSummary = null;
  if (role === 'trader') {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', `user:${user.get('email')}`);
    tradeQuery.descending('createdAt');
    tradeQuery.limit(10);
    trades = await tradeQuery.find({ useMasterKey: true });

    // Calculate trade summary
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

  // Get investments (for investors)
  let investments = [];
  let investmentSummary = null;
  if (role === 'investor') {
    const investmentQuery = new Parse.Query('Investment');
    investmentQuery.equalTo('investorId', userId);
    investmentQuery.descending('createdAt');
    investmentQuery.limit(10);
    investments = await investmentQuery.find({ useMasterKey: true });

    // Calculate investment summary
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

  // Get recent activity (last 10 audit logs for this user)
  const activityQuery = new Parse.Query('AuditLog');
  activityQuery.equalTo('resourceId', userId);
  activityQuery.descending('createdAt');
  activityQuery.limit(10);
  const activities = await activityQuery.find({ useMasterKey: true });

  // Helper to format dates safely
  const formatDate = (date) => {
    if (!date) return null;
    if (date instanceof Date) return date.toISOString();
    if (date.iso) return date.iso; // Parse Date object format
    return date;
  };

  // For traders: load investors for each trade
  const tradesWithInvestors = await Promise.all(trades.map(async (t) => {
    // Load pool participations for this trade
    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.equalTo('tradeId', t.id);
    const participations = await participationQuery.find({ useMasterKey: true });

    // Get investor details for each participation
    const investors = await Promise.all(participations.map(async (p) => {
      const investmentId = p.get('investmentId');
      // First try direct properties on participation (from iOS sync)
      let investorEmail = p.get('investorId'); // investorId often contains email like "user:email@test.com"
      let investorName = p.get('investorName');

      // If no direct investorName, try to get from Investment/User
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
          // Investor not found via Investment, use participation data
        }
      }

      // Clean up investorEmail if it's in "user:email" format
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
      investors: investors.filter(i => i.investorName), // Include investors with name
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

/**
 * Update user status.
 * Available to: admin (all statuses), customer_service (suspend/reactivate only)
 * NOT available to: compliance
 */
Parse.Cloud.define('updateUserStatus', async (request) => {
  const { userId, status, reason } = request.params;

  if (!userId || !status) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and status required');
  }

  // Check if user can change to this status
  requireStatusChangePermission(request, status);

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  const oldStatus = user.get('status');
  user.set('status', status);
  user.set('statusReason', reason);
  user.set('statusChangedAt', new Date());
  user.set('statusChangedBy', request.user.id);

  await user.save(null, { useMasterKey: true });

  // Audit log
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

// ============================================================================
// COMPLIANCE & AUDIT
// ============================================================================

/**
 * Get compliance events requiring review.
 * Available to: admin, compliance
 */
Parse.Cloud.define('getComplianceEvents', async (request) => {
  requirePermission(request, 'getComplianceEvents');

  const { severity, reviewed, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('ComplianceEvent');

  if (severity) query.equalTo('severity', severity);
  if (reviewed !== undefined) query.equalTo('reviewed', reviewed);

  query.descending('occurredAt');
  query.limit(limit);
  query.skip(skip);

  const events = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return { events: events.map(e => e.toJSON()), total };
});

/**
 * Mark compliance event as reviewed.
 * Available to: admin, compliance
 */
Parse.Cloud.define('reviewComplianceEvent', async (request) => {
  requirePermission(request, 'reviewComplianceEvent');

  const { eventId, notes } = request.params;

  if (!eventId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'eventId required');
  }

  const event = await new Parse.Query('ComplianceEvent').get(eventId, { useMasterKey: true });

  event.set('reviewed', true);
  event.set('reviewedBy', request.user.id);
  event.set('reviewedAt', new Date());
  event.set('reviewNotes', notes);

  await event.save(null, { useMasterKey: true });

  // Audit log
  await logPermissionCheck(request, 'reviewComplianceEvent', 'ComplianceEvent', eventId);

  return { success: true };
});

/**
 * Get audit logs.
 * Available to: admin, compliance
 */
Parse.Cloud.define('getAuditLogs', async (request) => {
  requirePermission(request, 'getAuditLogs');

  const { logType, action, userId, resourceType, limit = 100, skip = 0 } = request.params;

  const query = new Parse.Query('AuditLog');

  if (logType) query.equalTo('logType', logType);
  if (action) query.contains('action', action);
  if (userId) query.equalTo('userId', userId);
  if (resourceType) query.equalTo('resourceType', resourceType);

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const logs = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return { logs: logs.map(l => l.toJSON()), total };
});

// ============================================================================
// 4-EYES APPROVALS
// ============================================================================

/**
 * Get pending 4-eyes requests.
 * Available to: admin, compliance
 */
Parse.Cloud.define('getPendingApprovals', async (request) => {
  requirePermission(request, 'getPendingApprovals');

  const query = new Parse.Query('FourEyesRequest');
  query.equalTo('status', 'pending');
  query.lessThan('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
  query.descending('createdAt');

  // Don't show own requests (4-eyes principle)
  query.notEqualTo('requesterId', request.user.id);

  const requests = await query.find({ useMasterKey: true });

  return { requests: requests.map(r => r.toJSON()) };
});

/**
 * Approve 4-eyes request.
 * Available to: admin, compliance
 *
 * IMPORTANT: Cannot approve own request (4-eyes principle enforced)
 */
Parse.Cloud.define('approveRequest', async (request) => {
  requirePermission(request, 'approveRequest');

  const { requestId, notes } = request.params;

  if (!requestId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  // 4-eyes: Cannot approve own request
  if (req.get('requesterId') === request.user.id) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Cannot approve own request (4-eyes principle)'
    );
  }

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  req.set('status', 'approved');
  req.set('approverId', request.user.id);
  req.set('approverRole', request.user.get('role'));
  req.set('approverNotes', notes);
  req.set('approvedAt', new Date());

  await req.save(null, { useMasterKey: true });

  // Audit log
  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', 'approved');
  audit.set('performedBy', request.user.id);
  audit.set('performedByRole', request.user.get('role'));
  audit.set('notes', notes);
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });

  return { success: true };
});

/**
 * Reject 4-eyes request.
 * Available to: admin, compliance
 */
Parse.Cloud.define('rejectRequest', async (request) => {
  requirePermission(request, 'rejectRequest');

  const { requestId, reason } = request.params;

  if (!requestId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId and reason required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  req.set('status', 'rejected');
  req.set('approverId', request.user.id);
  req.set('approverRole', request.user.get('role'));
  req.set('rejectionReason', reason);
  req.set('rejectedAt', new Date());

  await req.save(null, { useMasterKey: true });

  // Audit log
  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', 'rejected');
  audit.set('performedBy', request.user.id);
  audit.set('performedByRole', request.user.get('role'));
  audit.set('notes', reason);
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });

  return { success: true };
});

// ============================================================================
// BUSINESS ADMIN FUNCTIONS (Financial/Accounting)
// ============================================================================

/**
 * Get financial dashboard summary.
 * Available to: admin, business_admin
 */
Parse.Cloud.define('getFinancialDashboard', async (request) => {
  requirePermission(request, 'getFinancialDashboard');

  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  // ========== INVESTMENTS ==========
  const investmentQuery = new Parse.Query('Investment');
  investmentQuery.containedIn('status', ['active', 'completed']);
  const investments = await investmentQuery.find({ useMasterKey: true });
  const totalInvestments = investments.reduce((sum, inv) => sum + (inv.get('amount') || 0), 0);

  // ========== TRADES (Revenue & Fees) ==========
  // Note: iOS app stores completed trades locally but backend trigger sets status='pending'
  // We check both 'completed' status AND trades with profit data
  const tradeQuery = new Parse.Query('Trade');
  const trades = await tradeQuery.find({ useMasterKey: true });

  console.log(`📊 getFinancialDashboard: Found ${trades.length} total trades`);

  // Calculate total revenue from trades
  // Backend stores: grossProfit, netProfit, totalFees (from trigger)
  // iOS stores: calculatedProfit, buyOrder.totalAmount, sellOrder.totalAmount
  const totalRevenue = trades.reduce((sum, trade) => {
    // Try both iOS format (nested orders) and backend format (direct fields)
    const buyOrder = trade.get('buyOrder') || {};
    const sellOrder = trade.get('sellOrder') || {};
    const sellOrders = trade.get('sellOrders') || [];

    // Method 1: From nested sellOrder (iOS format)
    let sellVolume = sellOrder.totalAmount || 0;
    if (sellOrders.length > 0) {
      sellVolume = sellOrders.reduce((s, order) => s + (order.totalAmount || 0), 0);
    }

    // Method 2: From buyOrder if no sell data (trade is open, count buy volume)
    if (sellVolume === 0 && buyOrder.totalAmount) {
      sellVolume = buyOrder.totalAmount;
    }

    return sum + sellVolume;
  }, 0);

  // Calculate total fees from trades (commissions)
  // Check both calculatedProfit (iOS) and grossProfit (backend trigger)
  const totalFees = trades.reduce((sum, trade) => {
    // Try iOS field first, then backend field
    const profit = trade.get('calculatedProfit') || trade.get('grossProfit') || 0;
    // Trader commission is 10% of gross profit
    const commission = profit > 0 ? profit * 0.10 : 0;
    return sum + commission;
  }, 0);

  // ========== MONTHLY STATS ==========
  const monthlyTradeQuery = new Parse.Query('Trade');
  monthlyTradeQuery.greaterThanOrEqualTo('createdAt', startOfMonth);
  const monthlyTrades = await monthlyTradeQuery.find({ useMasterKey: true });

  console.log(`📊 getFinancialDashboard: Found ${monthlyTrades.length} trades this month`);

  const monthlyRevenue = monthlyTrades.reduce((sum, trade) => {
    const buyOrder = trade.get('buyOrder') || {};
    const sellOrder = trade.get('sellOrder') || {};
    const sellOrders = trade.get('sellOrders') || [];

    let sellVolume = sellOrder.totalAmount || 0;
    if (sellOrders.length > 0) {
      sellVolume = sellOrders.reduce((s, order) => s + (order.totalAmount || 0), 0);
    }
    if (sellVolume === 0 && buyOrder.totalAmount) {
      sellVolume = buyOrder.totalAmount;
    }

    return sum + sellVolume;
  }, 0);

  const monthlyFees = monthlyTrades.reduce((sum, trade) => {
    const profit = trade.get('calculatedProfit') || trade.get('grossProfit') || 0;
    const commission = profit > 0 ? profit * 0.10 : 0;
    return sum + commission;
  }, 0);

  // ========== CORRECTIONS & ROUNDING ==========
  const correctionQuery = new Parse.Query('CorrectionRequest');
  correctionQuery.equalTo('status', 'pending');
  const pendingCorrections = await correctionQuery.count({ useMasterKey: true });

  const roundingQuery = new Parse.Query('RoundingDifference');
  roundingQuery.equalTo('status', 'open');
  const openRoundingDiffs = await roundingQuery.count({ useMasterKey: true });

  // Return in format expected by admin-portal
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
});

/**
 * Get rounding differences for review.
 * Available to: admin, business_admin
 */
Parse.Cloud.define('getRoundingDifferences', async (request) => {
  requirePermission(request, 'getRoundingDifferences');

  const { status, limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('RoundingDifference');

  if (status) {
    query.equalTo('status', status);
  } else {
    query.containedIn('status', ['open', 'under_review']);
  }

  query.descending('occurredAt');
  query.limit(limit);
  query.skip(skip);

  const differences = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return { differences: differences.map(d => d.toJSON()), total };
});

/**
 * Create a correction request (requires 4-eyes approval).
 * Available to: admin, business_admin
 */
Parse.Cloud.define('createCorrectionRequest', async (request) => {
  requirePermission(request, 'createCorrectionRequest');

  const {
    correctionType,
    targetId,
    targetType,
    reason,
    oldValue,
    newValue
  } = request.params;

  if (!correctionType || !targetId || !targetType || !reason) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'correctionType, targetId, targetType, and reason required'
    );
  }

  // Create 4-eyes request
  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const fourEyesReq = new FourEyesRequest();
  fourEyesReq.set('requestType', 'correction');
  fourEyesReq.set('requesterId', request.user.id);
  fourEyesReq.set('requesterRole', request.user.get('role'));
  fourEyesReq.set('status', 'pending');
  fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
  fourEyesReq.set('metadata', {
    correctionType,
    targetId,
    targetType,
    reason,
    oldValue,
    newValue,
  });
  await fourEyesReq.save(null, { useMasterKey: true });

  // Audit log
  await logPermissionCheck(request, 'createCorrectionRequest', targetType, targetId);

  return {
    success: true,
    fourEyesRequestId: fourEyesReq.id,
    message: 'Correction request created. Awaiting 4-eyes approval.'
  };
});

/**
 * Get correction requests for review.
 * Available to: admin, business_admin
 */
Parse.Cloud.define('getCorrectionRequests', async (request) => {
  requirePermission(request, 'getCorrectionRequests');

  const { status, limit = 50, skip = 0 } = request.params;

  // Query 4-eyes requests of type 'correction'
  const query = new Parse.Query('FourEyesRequest');
  query.equalTo('requestType', 'correction');

  if (status) {
    query.equalTo('status', status);
  }

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const requests = await query.find({ useMasterKey: true });

  // Transform to CorrectionRequest format expected by admin-portal
  const corrections = requests.map(req => {
    const metadata = req.get('metadata') || {};
    return {
      objectId: req.id,
      type: metadata.correctionType || 'unknown',
      amount: metadata.newValue || 0,
      currency: 'EUR',
      reason: metadata.reason || '',
      status: req.get('status'),
      requestedBy: req.get('requesterId'),
      createdAt: req.get('createdAt').toISOString(),
    };
  });

  return { corrections };
});

// ============================================================================
// SECURITY OFFICER FUNCTIONS
// ============================================================================

/**
 * Get security dashboard.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('getSecurityDashboard', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const now = new Date();
  const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const last7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  // Failed login attempts (last 24h)
  const failedLoginQuery = new Parse.Query('ComplianceEvent');
  failedLoginQuery.equalTo('eventType', 'failed_login_attempt');
  failedLoginQuery.greaterThanOrEqualTo('occurredAt', last24h);
  const failedLogins = await failedLoginQuery.count({ useMasterKey: true });

  // Suspicious activities (last 7d)
  const suspiciousQuery = new Parse.Query('ComplianceEvent');
  suspiciousQuery.containedIn('eventType', ['suspicious_activity', 'login_from_new_device']);
  suspiciousQuery.greaterThanOrEqualTo('occurredAt', last7d);
  const suspiciousActivities = await suspiciousQuery.count({ useMasterKey: true });

  // Locked accounts
  const lockedQuery = new Parse.Query(Parse.User);
  lockedQuery.equalTo('status', 'locked');
  const lockedAccounts = await lockedQuery.count({ useMasterKey: true });

  // Pending security reviews
  const reviewQuery = new Parse.Query('ComplianceEvent');
  reviewQuery.equalTo('requiresReview', true);
  reviewQuery.equalTo('reviewed', false);
  reviewQuery.containedIn('eventType', [
    'suspicious_activity',
    'failed_login_attempt',
    'login_from_new_device',
    'aml_check_failed'
  ]);
  const pendingSecurityReviews = await reviewQuery.count({ useMasterKey: true });

  return {
    failedLogins: { last24h: failedLogins },
    suspiciousActivities: { last7d: suspiciousActivities },
    accounts: { locked: lockedAccounts },
    reviews: { pending: pendingSecurityReviews },
  };
});

/**
 * Get login history for a user.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('getLoginHistory', async (request) => {
  requirePermission(request, 'getLoginHistory');

  const { userId, limit = 50 } = request.params;

  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const query = new Parse.Query('ComplianceEvent');
  query.equalTo('userId', userId);
  query.containedIn('eventType', [
    'account_created',
    'login_from_new_device',
    'failed_login_attempt',
    'password_changed',
    'two_factor_enabled'
  ]);
  query.descending('occurredAt');
  query.limit(limit);

  const events = await query.find({ useMasterKey: true });

  // Log access for audit trail
  await logPermissionCheck(request, 'getLoginHistory', 'User', userId);

  return { events: events.map(e => e.toJSON()) };
});

/**
 * Force terminate a user session.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('terminateUserSession', async (request) => {
  requirePermission(request, 'terminateUserSession');

  const { userId, reason } = request.params;

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason required');
  }

  // Get all sessions for user
  const sessionQuery = new Parse.Query(Parse.Session);
  const userPointer = new Parse.User();
  userPointer.id = userId;
  sessionQuery.equalTo('user', userPointer);

  const sessions = await sessionQuery.find({ useMasterKey: true });

  // Delete all sessions
  await Parse.Object.destroyAll(sessions, { useMasterKey: true });

  // Audit log
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'security');
  log.set('action', 'terminate_user_sessions');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('metadata', { reason, sessionsTerminated: sessions.length });
  await log.save(null, { useMasterKey: true });

  // Log compliance event
  const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
  const event = new ComplianceEvent();
  event.set('userId', userId);
  event.set('eventType', 'account_suspended');
  event.set('severity', 'medium');
  event.set('description', `Sessions terminated by ${request.user.get('role')}: ${reason}`);
  event.set('metadata', {
    terminatedBy: request.user.id,
    terminatedByRole: request.user.get('role'),
    reason
  });
  await event.save(null, { useMasterKey: true });

  return {
    success: true,
    sessionsTerminated: sessions.length
  };
});

/**
 * Force password reset for a user.
 * Available to: admin, security_officer, customer_service
 */
Parse.Cloud.define('forcePasswordReset', async (request) => {
  requirePermission(request, 'forcePasswordReset');

  const { userId, reason } = request.params;

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  // Generate reset token
  const resetToken = Math.random().toString(36).substring(2, 15) +
                     Math.random().toString(36).substring(2, 15);

  user.set('passwordResetToken', resetToken);
  user.set('passwordResetExpires', new Date(Date.now() + 24 * 60 * 60 * 1000));
  user.set('requiresPasswordChange', true);
  await user.save(null, { useMasterKey: true });

  // Audit log
  await logPermissionCheck(request, 'forcePasswordReset', 'User', userId);

  // TODO: Send email with reset link

  return {
    success: true,
    message: 'Password reset initiated. User will be required to change password on next login.'
  };
});

// ============================================================================
// PERMISSIONS INFO (for UI)
// ============================================================================

/**
 * Get permissions for current user's role.
 * Useful for UI to show/hide features.
 */
Parse.Cloud.define('getMyPermissions', async (request) => {
  requireAdminRole(request);

  const { getPermissionsForRole, isElevatedRole } = require('../utils/permissions');
  const role = request.user.get('role');
  const permissions = getPermissionsForRole(role);

  return {
    role,
    permissions,
    isFullAdmin: permissions[0] === '*',
    isElevated: isElevatedRole(role),
    roleDescription: getRoleDescription(role),
  };
});

/**
 * Get description for a role.
 */
function getRoleDescription(role) {
  const descriptions = {
    admin: 'Full App Administrator',
    business_admin: 'Business/Accounting Administrator',
    security_officer: 'Security Officer',
    compliance: 'Compliance Officer',
    customer_service: 'Customer Service Representative',
    system: 'System Process',
  };
  return descriptions[role] || role;
}

/**
 * Get all available admin roles and their descriptions.
 * Available to: admin only
 */
Parse.Cloud.define('getAdminRoles', async (request) => {
  requirePermission(request, '*'); // admin only

  const { getAdminRoles } = require('../utils/permissions');
  const roles = getAdminRoles();

  return {
    roles: roles.map(role => ({
      id: role,
      name: getRoleDescription(role),
      isElevated: isElevatedRole(role),
    })),
  };
});

/**
 * Get user details without auth (development only)
 * TODO: Remove in production
 */
Parse.Cloud.define('getTestUserDetails', async (request) => {
  const { userId } = request.params;
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const role = user.get('role');

  // Get trades (for traders)
  let trades = [];
  let tradeSummary = null;
  if (role === 'trader') {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.equalTo('traderId', `user:${user.get('email')}`);
    tradeQuery.descending('createdAt');
    tradeQuery.limit(10);
    const rawTrades = await tradeQuery.find({ useMasterKey: true });

    // Load investors for each trade
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

    // Summary
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
});

/**
 * Reset password for development user (development only)
 * TODO: Remove in production
 */
Parse.Cloud.define('resetDevUserPassword', async (request) => {
  const { email } = request.params;
  const newPassword = 'DevTest123!Secure';

  const query = new Parse.Query(Parse.User);
  query.equalTo('email', email);
  const user = await query.first({ useMasterKey: true });

  if (!user) {
    return { success: false, message: 'User not found' };
  }

  user.set('password', newPassword);
  await user.save(null, { useMasterKey: true });

  return {
    success: true,
    message: `Password reset for ${email}`,
    newPassword: newPassword,
    objectId: user.id
  };
});

/**
 * Create test users for development (admin only)
 */
Parse.Cloud.define('createTestUsers', async (request) => {
  console.log('📊 Creating test users...');

  const testUsers = [
    { username: 'trader3@test.com', email: 'trader3@test.com', role: 'trader', status: 'active' },
    { username: 'investor1@test.com', email: 'investor1@test.com', role: 'investor', status: 'active' },
    { username: 'investor2@test.com', email: 'investor2@test.com', role: 'investor', status: 'active' },
  ];

  const created = [];
  for (const userData of testUsers) {
    // Check if user already exists
    const existingQuery = new Parse.Query(Parse.User);
    existingQuery.equalTo('email', userData.email);
    const existing = await existingQuery.first({ useMasterKey: true });

    if (existing) {
      created.push({ email: userData.email, status: 'already exists', objectId: existing.id });
      continue;
    }

    const user = new Parse.User();
    user.set('username', userData.username);
    user.set('email', userData.email);
    user.set('password', 'TestPassword123!Secure');
    user.set('role', userData.role);
    user.set('status', userData.status);

    await user.signUp(null, { useMasterKey: true });
    created.push({ email: userData.email, status: 'created', objectId: user.id });
  }

  return { success: true, users: created };
});

/**
 * Get trades with investors (development endpoint for testing)
 * Returns trades with their pool participations directly
 */
Parse.Cloud.define('getTradesWithInvestors', async (request) => {
  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.descending('tradeNumber');
  tradeQuery.limit(10);
  const trades = await tradeQuery.find({ useMasterKey: true });

  const result = await Promise.all(trades.map(async (trade) => {
    const participationQuery = new Parse.Query('PoolTradeParticipation');
    participationQuery.equalTo('tradeId', trade.id);
    const participations = await participationQuery.find({ useMasterKey: true });

    return {
      objectId: trade.id,
      tradeNumber: trade.get('tradeNumber'),
      symbol: trade.get('symbol'),
      description: trade.get('description'),
      status: trade.get('status'),
      grossProfit: trade.get('grossProfit'),
      totalFees: trade.get('totalFees'),
      traderId: trade.get('traderId'),
      createdAt: trade.get('createdAt'),
      completedAt: trade.get('completedAt'),
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

  return { trades: result };
});

/**
 * Create test data for PoolTradeParticipation (development only)
 * This allows testing the investor list feature in the admin portal
 */
Parse.Cloud.define('createTestPoolParticipations', async (request) => {
  // Development only - remove in production
  console.log('📊 Creating test PoolTradeParticipations...');

  // Get existing trades
  const tradeQuery = new Parse.Query('Trade');
  tradeQuery.descending('tradeNumber');
  tradeQuery.limit(5);
  const trades = await tradeQuery.find({ useMasterKey: true });

  if (trades.length === 0) {
    return { success: false, message: 'No trades found' };
  }

  const created = [];

  // Test investors
  const testInvestors = [
    { id: 'user:investor1@test.com', name: 'Investor One' },
    { id: 'user:investor2@test.com', name: 'Investor Two' },
  ];

  for (const trade of trades) {
    const tradeId = trade.id;
    const traderId = trade.get('traderId');
    const buyOrder = trade.get('buyOrder') || {};
    const totalAmount = buyOrder.totalAmount || 10000;
    const grossProfit = trade.get('grossProfit') || 0;

    // Create 2 participations per trade
    for (let i = 0; i < testInvestors.length; i++) {
      const investor = testInvestors[i];
      const ownershipPct = i === 0 ? 0.40 : 0.35; // 40% and 35%
      const allocatedAmount = totalAmount * ownershipPct;
      const profitShare = grossProfit * ownershipPct;

      const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');
      const participation = new PoolParticipation();

      participation.set('tradeId', tradeId);
      participation.set('investmentId', `inv-test-${trade.get('tradeNumber')}-${i+1}`);
      participation.set('investorId', investor.id);
      participation.set('investorName', investor.name);
      participation.set('traderId', traderId);
      participation.set('poolReservationId', `pool-res-${trade.get('tradeNumber')}-${i+1}`);
      participation.set('poolNumber', i + 1);
      participation.set('allocatedAmount', allocatedAmount);
      participation.set('totalTradeValue', totalAmount);
      participation.set('ownershipPercentage', ownershipPct);
      participation.set('profitShare', profitShare);
      participation.set('isSettled', trade.get('status') === 'completed');

      await participation.save(null, { useMasterKey: true });
      created.push({
        tradeNumber: trade.get('tradeNumber'),
        investor: investor.name,
        ownershipPct: `${(ownershipPct * 100).toFixed(0)}%`,
        profitShare: profitShare.toFixed(2)
      });
    }
  }

  console.log(`✅ Created ${created.length} test participations`);
  return {
    success: true,
    message: `Created ${created.length} participations for ${trades.length} trades`,
    participations: created
  };
});

/**
 * Initialize missing Parse schemas for new API services
 * Creates: Watchlist, SavedFilter, InvestorWatchlist, PushToken
 * Available to: admin only (uses masterKey internally)
 */
Parse.Cloud.define('initializeNewSchemas', async (request) => {
  requireAdminRole(request);
  console.log('🔧 Initializing new schemas...');

  const results = [];

  // 1. Watchlist Schema (Securities Watchlist)
  try {
    const Watchlist = Parse.Object.extend('Watchlist');
    const testWatchlist = new Watchlist();
    testWatchlist.set('userId', 'schema-init');
    testWatchlist.set('symbol', 'INIT');
    testWatchlist.set('addedAt', new Date());
    testWatchlist.set('notes', '');
    testWatchlist.set('alertPriceAbove', 0);
    testWatchlist.set('alertPriceBelow', 0);
    testWatchlist.set('notifyOnChange', false);
    await testWatchlist.save(null, { useMasterKey: true });
    await testWatchlist.destroy({ useMasterKey: true });
    results.push({ class: 'Watchlist', status: 'created' });
  } catch (error) {
    results.push({ class: 'Watchlist', status: 'error', message: error.message });
  }

  // 2. SavedFilter Schema
  try {
    const SavedFilter = Parse.Object.extend('SavedFilter');
    const testFilter = new SavedFilter();
    testFilter.set('userId', 'schema-init');
    testFilter.set('name', 'Init Filter');
    testFilter.set('filterContext', 'securities_search');
    testFilter.set('filterCriteria', {});
    testFilter.set('isDefault', false);
    await testFilter.save(null, { useMasterKey: true });
    await testFilter.destroy({ useMasterKey: true });
    results.push({ class: 'SavedFilter', status: 'created' });
  } catch (error) {
    results.push({ class: 'SavedFilter', status: 'error', message: error.message });
  }

  // 3. InvestorWatchlist Schema
  try {
    const InvestorWatchlist = Parse.Object.extend('InvestorWatchlist');
    const testInvWatchlist = new InvestorWatchlist();
    testInvWatchlist.set('investorId', 'schema-init');
    testInvWatchlist.set('traderId', 'schema-init');
    testInvWatchlist.set('traderName', 'Init Trader');
    testInvWatchlist.set('traderSpecialization', '');
    testInvWatchlist.set('traderRiskClass', 1);
    testInvWatchlist.set('notes', '');
    testInvWatchlist.set('targetInvestmentAmount', 0);
    testInvWatchlist.set('notifyOnNewTrade', false);
    testInvWatchlist.set('notifyOnPerformanceChange', false);
    testInvWatchlist.set('sortOrder', 0);
    testInvWatchlist.set('addedAt', new Date());
    await testInvWatchlist.save(null, { useMasterKey: true });
    await testInvWatchlist.destroy({ useMasterKey: true });
    results.push({ class: 'InvestorWatchlist', status: 'created' });
  } catch (error) {
    results.push({ class: 'InvestorWatchlist', status: 'error', message: error.message });
  }

  // 4. PushToken Schema (if not exists)
  try {
    const PushToken = Parse.Object.extend('PushToken');
    const testToken = new PushToken();
    testToken.set('userId', 'schema-init');
    testToken.set('token', 'init-token');
    testToken.set('tokenType', 'apns');
    testToken.set('deviceId', 'init-device');
    testToken.set('isActive', false);
    testToken.set('lastValidatedAt', new Date());
    testToken.set('validationFailures', 0);
    await testToken.save(null, { useMasterKey: true });
    await testToken.destroy({ useMasterKey: true });
    results.push({ class: 'PushToken', status: 'created' });
  } catch (error) {
    results.push({ class: 'PushToken', status: 'error', message: error.message });
  }

  console.log('✅ Schema initialization complete:', results);
  return {
    success: true,
    message: 'Schema initialization complete',
    results
  };
});
