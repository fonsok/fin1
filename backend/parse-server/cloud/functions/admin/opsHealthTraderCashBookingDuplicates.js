'use strict';

const {
  loadOpsHealthSnapshot,
  evaluateOpsHealthSnapshot,
} = require('./opsHealthSnapshotReader');

const SNAPSHOT_ID = 'trader-cash-booking-duplicates';

async function handleGetTraderCashBookingDuplicatesStatus(_request) {
  const snapshot = await loadOpsHealthSnapshot(SNAPSHOT_ID);
  const base = evaluateOpsHealthSnapshot({
    snapshot,
    snapshotId: SNAPSHOT_ID,
    isUnhealthy: ({ snapshot: snap, healthyFlag }) => {
      const violationCount = Number(snap.get('violationCount') || 0);
      return violationCount > 0 || !healthyFlag;
    },
    unhealthyReason: ({ snapshot: snap }) => {
      const violationCount = Number(snap.get('violationCount') || 0);
      return `${violationCount} duplicate trader cash booking group(s) detected`;
    },
  });

  if (!snapshot) return base;

  const violationSamples = Array.isArray(snapshot.get('violationSamples'))
    ? snapshot.get('violationSamples')
    : [];

  return Object.assign(base, {
    violationCount: Number(snapshot.get('violationCount') || 0),
    byTradeId: Number(snapshot.get('byTradeId') || 0),
    byBusinessCaseId: Number(snapshot.get('byBusinessCaseId') || 0),
    byTradeNumber: Number(snapshot.get('byTradeNumber') || 0),
    duplicateInvoicesByOrder: Number(snapshot.get('duplicateInvoicesByOrder') || 0),
    duplicateClientInvoiceDocs: Number(snapshot.get('duplicateClientInvoiceDocs') || 0),
    violationSamples: violationSamples.slice(0, 25),
  });
}

module.exports = {
  handleGetTraderCashBookingDuplicatesStatus,
  SNAPSHOT_ID,
};
