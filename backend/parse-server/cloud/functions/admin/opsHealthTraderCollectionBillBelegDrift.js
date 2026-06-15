'use strict';

const { inspectTraderCollectionBillBelegDrift } = require('../../utils/accountingHelper/traderCollectionBillBelegSnapshot/belegDriftInspect');

/**
 * Live guard: trader TBC/TSC snapshot text vs persisted metadata (GoB SSOT).
 */
async function handleGetTraderCollectionBillBelegDriftStatus(request) {
  const params = request.params || {};
  const limit = Math.min(200, Math.max(1, Number(params.limit) || 75));
  // SSOT drift guard: snapshot ↔ metadata only (invoice optional for deep inspect).
  const includeInvoice = params.includeInvoice === true;

  const report = await inspectTraderCollectionBillBelegDrift({
    limit,
    skip: 0,
    includeInvoice,
  });

  let overall = 'healthy';
  if (report.drifted > 0) overall = 'degraded';
  else if (report.needsBackfill > 0) overall = 'degraded';

  return {
    overall,
    checkedAt: report.checkedAt,
    checkedDocuments: report.examined,
    healthyDocuments: report.healthy,
    needsBackfillDocuments: report.needsBackfill,
    driftedDocuments: report.drifted,
    includeInvoice,
    reason: report.drifted > 0
      ? `${report.drifted} trader collection bill(s) drift between snapshot and metadata`
      : (report.needsBackfill > 0
        ? `${report.needsBackfill} trader collection bill(s) need SSOT backfill`
        : null),
    driftSamples: (report.samples || []).slice(0, 15),
    repairHint: report.repairHint,
  };
}

module.exports = {
  handleGetTraderCollectionBillBelegDriftStatus,
};
