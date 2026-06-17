'use strict';

const { audit } = require('../../utils/structuredLogger');
const { inspectUserCashBalanceDrift } = require('../../utils/accountingHelper/userCashBalanceDriftInspect');

/**
 * Admin: inspect UserCashBalance vs customer merge timeline drift.
 */
async function handleInspectUserCashBalanceDrift(request) {
  const params = request.params || {};
  const report = await inspectUserCashBalanceDrift(params);

  audit.info('admin.userCashBalance.driftInspect', {
    examined: report.examined,
    alignedUsers: report.alignedUsers,
    drifted: report.drifted,
    missingRows: report.missingRows,
    skipped: report.skipped,
    healthy: report.healthy,
    message: 'checkUserCashBalanceDrift completed',
  });

  return report;
}

module.exports = {
  handleInspectUserCashBalanceDrift,
};
