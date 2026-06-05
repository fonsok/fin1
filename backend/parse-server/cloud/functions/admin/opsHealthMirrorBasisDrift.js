'use strict';

const {
  loadOpsHealthSnapshot,
  evaluateOpsHealthSnapshot,
} = require('./opsHealthSnapshotReader');

const SNAPSHOT_ID = 'mirror-basis-drift';

async function handleGetMirrorBasisDriftStatus(_request) {
  const snapshot = await loadOpsHealthSnapshot(SNAPSHOT_ID);
  const base = evaluateOpsHealthSnapshot({
    snapshot,
    snapshotId: SNAPSHOT_ID,
    isUnhealthy: ({ snapshot: snap, healthyFlag }) => {
      const driftedDocuments = Number(snap.get('driftedDocuments') || 0);
      return driftedDocuments > 0 || !healthyFlag;
    },
    unhealthyReason: ({ snapshot: snap }) => {
      const driftedDocuments = Number(snap.get('driftedDocuments') || 0);
      return `${driftedDocuments} investorCollectionBill document(s) drifted from mirror-basis SSOT`;
    },
  });

  if (!snapshot) return base;

  const driftSamples = Array.isArray(snapshot.get('driftSamples'))
    ? snapshot.get('driftSamples')
    : [];

  return Object.assign(base, {
    checkedDocuments: Number(snapshot.get('checkedDocuments') || 0),
    driftedDocuments: Number(snapshot.get('driftedDocuments') || 0),
    nullDerivedCount: Number(snapshot.get('nullDerivedCount') || 0),
    commissionRate: snapshot.get('commissionRate') ?? null,
    epsilonPp: snapshot.get('epsilonPp') ?? null,
    driftSamples: driftSamples.slice(0, 25),
  });
}

module.exports = {
  handleGetMirrorBasisDriftStatus,
  SNAPSHOT_ID,
};
