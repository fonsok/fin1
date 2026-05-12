'use strict';

const {
  FRESHNESS_WARN_SECONDS,
  FRESHNESS_FAIL_SECONDS,
} = require('./opsHealthConstants');

async function handleGetMirrorBasisDriftStatus(_request) {
  const query = new Parse.Query('OpsHealthSnapshot');
  let snapshot;
  try {
    snapshot = await query.get('mirror-basis-drift', { useMasterKey: true });
  } catch (err) {
    if (err && err.code === Parse.Error.OBJECT_NOT_FOUND) {
      return {
        overall: 'unknown',
        hasSnapshot: false,
        reason: 'no snapshot yet — first cron run has not completed',
      };
    }
    throw err;
  }

  const runAt = snapshot.get('runAt') || snapshot.get('updatedAt') || snapshot.updatedAt;
  const runAtIso = runAt ? new Date(runAt).toISOString() : null;
  const ageSeconds = runAt ? Math.max(0, Math.floor((Date.now() - new Date(runAt).getTime()) / 1000)) : null;

  const driftedDocuments = Number(snapshot.get('driftedDocuments') || 0);
  const checkedDocuments = Number(snapshot.get('checkedDocuments') || 0);
  const nullDerivedCount = Number(snapshot.get('nullDerivedCount') || 0);
  const healthyFlag = Boolean(snapshot.get('healthy'));

  let overall = 'healthy';
  let reason = null;
  if (driftedDocuments > 0 || !healthyFlag) {
    overall = 'degraded';
    reason = `${driftedDocuments} investorCollectionBill document(s) drifted from mirror-basis SSOT`;
  } else if (ageSeconds === null) {
    overall = 'unknown';
    reason = 'snapshot has no timestamp';
  } else if (ageSeconds > FRESHNESS_FAIL_SECONDS) {
    overall = 'down';
    reason = `snapshot is stale (${Math.floor(ageSeconds / 86400)} days old)`;
  } else if (ageSeconds > FRESHNESS_WARN_SECONDS) {
    overall = 'degraded';
    reason = `snapshot is getting stale (${Math.floor(ageSeconds / 86400)} days old)`;
  }

  const driftSamples = Array.isArray(snapshot.get('driftSamples'))
    ? snapshot.get('driftSamples')
    : [];

  return {
    overall,
    hasSnapshot: true,
    runAt: runAtIso,
    ageSeconds,
    healthy: healthyFlag,
    checkedDocuments,
    driftedDocuments,
    nullDerivedCount,
    commissionRate: snapshot.get('commissionRate') ?? null,
    epsilonPp: snapshot.get('epsilonPp') ?? null,
    driftSamples: driftSamples.slice(0, 25),
    reason,
  };
}

module.exports = {
  handleGetMirrorBasisDriftStatus,
};
