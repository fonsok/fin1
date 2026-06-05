'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { computeSupportTrends } = require('../../utils/supportTrendsAggregator');

/**
 * Server-side support trend aggregation (scales beyond 500 tickets/week).
 */
Parse.Cloud.define('getSupportTrends', async (request) => {
  requireAdminRole(request);

  const weeksBack = Math.min(Math.max(Number(request.params?.weeksBack) || 2, 1), 8);
  const result = await computeSupportTrends({ weeksBack });

  return {
    success: true,
    trends: result.trends,
    meta: result.meta,
  };
});
