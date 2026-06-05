'use strict';

const {
  FRESHNESS_WARN_SECONDS,
  FRESHNESS_FAIL_SECONDS,
} = require('./opsHealthConstants');

async function loadOpsHealthSnapshot(snapshotId) {
  const query = new Parse.Query('OpsHealthSnapshot');
  try {
    return await query.get(snapshotId, { useMasterKey: true });
  } catch (err) {
    if (err && err.code === Parse.Error.OBJECT_NOT_FOUND) return null;
    throw err;
  }
}

function snapshotRunAtIso(snapshot) {
  const runAt = snapshot.get('runAt') || snapshot.get('updatedAt') || snapshot.updatedAt;
  return runAt ? new Date(runAt).toISOString() : null;
}

function snapshotAgeSeconds(snapshot) {
  const runAt = snapshot.get('runAt') || snapshot.get('updatedAt') || snapshot.updatedAt;
  if (!runAt) return null;
  return Math.max(0, Math.floor((Date.now() - new Date(runAt).getTime()) / 1000));
}

/**
 * Standard snapshot health: unhealthy metric → degraded; stale → down; missing → unknown.
 */
function evaluateOpsHealthSnapshot({
  snapshot,
  snapshotId,
  isUnhealthy,
  unhealthyReason,
  unknownReason = 'no snapshot yet — first cron run has not completed',
}) {
  if (!snapshot) {
    return {
      overall: 'unknown',
      hasSnapshot: false,
      snapshotId,
      reason: unknownReason,
    };
  }

  const runAtIso = snapshotRunAtIso(snapshot);
  const ageSeconds = snapshotAgeSeconds(snapshot);
  const healthyFlag = Boolean(snapshot.get('healthy'));

  let overall = 'healthy';
  let reason = null;

  if (isUnhealthy({ snapshot, healthyFlag })) {
    overall = 'degraded';
    reason = unhealthyReason({ snapshot, healthyFlag });
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

  return {
    overall,
    hasSnapshot: true,
    snapshotId,
    runAt: runAtIso,
    ageSeconds,
    healthy: healthyFlag,
    reason,
  };
}

module.exports = {
  loadOpsHealthSnapshot,
  snapshotRunAtIso,
  snapshotAgeSeconds,
  evaluateOpsHealthSnapshot,
};
