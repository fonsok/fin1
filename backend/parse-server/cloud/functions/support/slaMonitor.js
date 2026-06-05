'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { processSlaAutoEscalations } = require('../../utils/supportSlaMonitor');

/**
 * Manual/on-demand SLA auto-escalation run (admin / ops).
 * Background loop: see main.js SLAMonitorWorker.
 */
Parse.Cloud.define('runSlaAutoEscalation', async (request) => {
  requireAdminRole(request);

  const role = request.user?.get('role');
  if (!['admin', 'compliance', 'customer_service'].includes(role)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'SLA job requires admin or CSR lead');
  }

  const { limit } = request.params || {};
  const result = await processSlaAutoEscalations({
    limit: limit ? Math.min(Number(limit), 500) : undefined,
  });

  return { success: true, ...result };
});
