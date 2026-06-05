'use strict';

const { logPermissionCheck } = require('../../utils/permissions');
const { reconcileStaleSettlementRetryJobs } = require('../../utils/accountingHelper/settlementRetryRepair');

async function handleReconcileStaleSettlementRetryJobs(request) {
  const params = request.params || {};
  const dryRun = params.dryRun !== false;
  const limit = Number(params.limit || 100);
  const requeueRecoverable = params.requeueRecoverable !== false;
  const runQueueAfter = Boolean(params.runQueueAfter);

  const result = await reconcileStaleSettlementRetryJobs({
    dryRun,
    limit,
    requeueRecoverable,
    runQueueAfter,
  });

  if (!request.master) {
    await logPermissionCheck(request, 'reconcileStaleSettlementRetryJobs', 'SettlementRetryJob', 'reconcile');
  }

  return {
    ...result,
    ranAt: new Date().toISOString(),
  };
}

module.exports = {
  handleReconcileStaleSettlementRetryJobs,
};
