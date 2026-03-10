'use strict';

const { requirePermission } = require('../../utils/permissions');

/**
 * Get admin dashboard statistics.
 * Available to: admin, customer_service (limited), compliance
 */
Parse.Cloud.define('getAdminDashboard', async (request) => {
  requirePermission(request, 'getAdminDashboard');

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const role = request.user.get('role');

  const totalUsers = await new Parse.Query(Parse.User)
    .equalTo('status', 'active')
    .count({ useMasterKey: true });
  const newUsersToday = await new Parse.Query(Parse.User)
    .greaterThanOrEqualTo('createdAt', today)
    .count({ useMasterKey: true });

  const openTickets = await new Parse.Query('SupportTicket')
    .containedIn('status', ['open', 'in_progress'])
    .count({ useMasterKey: true });

  const response = {
    users: { total: totalUsers, newToday: newUsersToday },
    support: { openTickets },
  };

  if (role === 'admin' || role === 'compliance') {
    const activeInvestments = await new Parse.Query('Investment')
      .equalTo('status', 'active')
      .count({ useMasterKey: true });

    const invQuery = new Parse.Query('Investment');
    invQuery.equalTo('status', 'active');
    const investments = await invQuery.find({ useMasterKey: true });
    let totalInvested = 0;
    investments.forEach(i => totalInvested += i.get('amount') || 0);

    const openTrades = await new Parse.Query('Trade')
      .containedIn('status', ['active', 'partial'])
      .count({ useMasterKey: true });

    const pendingReviews = await new Parse.Query('ComplianceEvent')
      .equalTo('requiresReview', true)
      .equalTo('reviewed', false)
      .count({ useMasterKey: true });

    const pendingApprovals = await new Parse.Query('FourEyesRequest')
      .equalTo('status', 'pending')
      .count({ useMasterKey: true });

    response.investments = { active: activeInvestments, totalAmount: totalInvested };
    response.trading = { openTrades };
    response.compliance = { pendingReviews, pendingApprovals };
  }

  return response;
});
