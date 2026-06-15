'use strict';

const { audit } = require('../../utils/structuredLogger');
const { inspectTraderCollectionBillBelegDrift } = require('../../utils/accountingHelper/traderCollectionBillBelegSnapshot/belegDriftInspect');

/**
 * Admin: inspect trader collection bill SSOT drift (snapshot ↔ metadata ↔ optional invoice).
 */
async function handleInspectTraderCollectionBillBelegDrift(request) {
  const params = request.params || {};
  const report = await inspectTraderCollectionBillBelegDrift(params);

  audit.info('admin.traderBeleg.driftInspect', {
    examined: report.examined,
    drifted: report.drifted,
    needsBackfill: report.needsBackfill,
    message: 'checkTraderCollectionBillBelegDrift completed',
  });

  return report;
}

module.exports = {
  handleInspectTraderCollectionBillBelegDrift,
};
