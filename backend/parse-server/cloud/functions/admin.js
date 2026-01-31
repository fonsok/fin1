// ============================================================================
// FIN1 Parse Cloud Code
// functions/admin.js - Admin Functions
// ============================================================================

'use strict';

// Verify admin role
async function requireAdmin(request) {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  const role = request.user.get('role');
  if (!['admin', 'customer_service', 'compliance'].includes(role)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required');
  }
}

// Get dashboard stats
Parse.Cloud.define('getAdminDashboard', async (request) => {
  await requireAdmin(request);

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  // Users
  const totalUsers = await new Parse.Query(Parse.User).equalTo('status', 'active').count({ useMasterKey: true });
  const newUsersToday = await new Parse.Query(Parse.User).greaterThanOrEqualTo('createdAt', today).count({ useMasterKey: true });

  // Investments
  const activeInvestments = await new Parse.Query('Investment').equalTo('status', 'active').count({ useMasterKey: true });

  const invQuery = new Parse.Query('Investment');
  invQuery.equalTo('status', 'active');
  const investments = await invQuery.find({ useMasterKey: true });
  let totalInvested = 0;
  investments.forEach(i => totalInvested += i.get('amount') || 0);

  // Trades
  const openTrades = await new Parse.Query('Trade').containedIn('status', ['active', 'partial']).count({ useMasterKey: true });

  // Support
  const openTickets = await new Parse.Query('SupportTicket').containedIn('status', ['open', 'in_progress']).count({ useMasterKey: true });

  // Compliance
  const pendingReviews = await new Parse.Query('ComplianceEvent')
    .equalTo('requiresReview', true)
    .equalTo('reviewed', false)
    .count({ useMasterKey: true });

  // Pending approvals
  const pendingApprovals = await new Parse.Query('FourEyesRequest').equalTo('status', 'pending').count({ useMasterKey: true });

  return {
    users: { total: totalUsers, newToday: newUsersToday },
    investments: { active: activeInvestments, totalAmount: totalInvested },
    trading: { openTrades },
    support: { openTickets },
    compliance: { pendingReviews, pendingApprovals }
  };
});

// Search users
Parse.Cloud.define('searchUsers', async (request) => {
  await requireAdmin(request);

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
      id: u.id,
      customerId: u.get('customerId'),
      email: u.get('email'),
      role: u.get('role'),
      status: u.get('status'),
      kycStatus: u.get('kycStatus'),
      createdAt: u.get('createdAt')
    })),
    total
  };
});

// Update user status
Parse.Cloud.define('updateUserStatus', async (request) => {
  await requireAdmin(request);

  const { userId, status, reason } = request.params;

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  const oldStatus = user.get('status');
  user.set('status', status);
  user.set('statusReason', reason);
  user.set('statusChangedAt', new Date());
  user.set('statusChangedBy', request.user.id);

  await user.save(null, { useMasterKey: true });

  // Log
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', 'update_user_status');
  log.set('userId', request.user.id);
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('oldValues', { status: oldStatus });
  log.set('newValues', { status, reason });
  await log.save(null, { useMasterKey: true });

  return { success: true };
});

// Get pending 4-eyes requests
Parse.Cloud.define('getPendingApprovals', async (request) => {
  await requireAdmin(request);

  const query = new Parse.Query('FourEyesRequest');
  query.equalTo('status', 'pending');
  query.lessThan('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)); // Not expired
  query.descending('createdAt');

  // Don't show own requests
  query.notEqualTo('requesterId', request.user.id);

  const requests = await query.find({ useMasterKey: true });

  return { requests: requests.map(r => r.toJSON()) };
});

// Approve 4-eyes request
Parse.Cloud.define('approveRequest', async (request) => {
  await requireAdmin(request);

  const { requestId, notes } = request.params;

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (req.get('requesterId') === request.user.id) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot approve own request');
  }

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  req.set('status', 'approved');
  req.set('approverId', request.user.id);
  req.set('approverNotes', notes);
  req.set('approvedAt', new Date());

  await req.save(null, { useMasterKey: true });

  // Log audit
  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', 'approved');
  audit.set('performedBy', request.user.id);
  audit.set('notes', notes);
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });

  return { success: true };
});
