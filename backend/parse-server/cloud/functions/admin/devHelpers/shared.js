'use strict';

/** True only while devResetTradingTestData is running its destroy loop (same Node process). */
let devTradingDataResetDestroyActive = false;

function runWithDevTradingDataResetDestroy(fn) {
  return Promise.resolve()
    .then(() => {
      devTradingDataResetDestroyActive = true;
      return fn();
    })
    .finally(() => {
      devTradingDataResetDestroyActive = false;
    });
}

function isDevTradingDataResetDestroyActive() {
  return devTradingDataResetDestroyActive === true;
}

function envTrue(name) {
  return String(process.env[name] || '').toLowerCase() === 'true';
}

async function writeDevMaintenanceAudit({
  action,
  request,
  payload,
}) {
  try {
    const AuditLog = Parse.Object.extend('AuditLog');
    const log = new AuditLog();
    log.set('logType', 'admin');
    log.set('action', action);
    log.set('userId', request.user?.id || 'system');
    log.set('resourceType', 'DevMaintenance');
    log.set('resourceId', action);
    log.set('metadata', {
      timestamp: new Date().toISOString(),
      payload,
    });
    await log.save(null, { useMasterKey: true });
  } catch (err) {
    console.error('Failed to write dev maintenance audit:', err.message);
  }
}

async function countAll(className) {
  const q = new Parse.Query(className);
  return q.count({ useMasterKey: true });
}

/** Passed to destroy so triggers can allow guarded dev-maintenance deletes (see triggers/legal.js). */
const DEV_TRADING_DATA_RESET_DESTROY_OPTIONS = Object.freeze({
  useMasterKey: true,
  context: { allowDevTradingDataReset: true },
});

/**
 * Batch delete for DEV reset. Uses destroyAll when possible; on AGGREGATE_ERROR (600) falls back to
 * per-object destroy and skips OBJECT_NOT_FOUND (101) — e.g. legacy rows with non-Parse objectId shapes.
 */
async function destroyParseObjectsTolerant(objects) {
  if (!objects || objects.length === 0) return 0;
  try {
    await Parse.Object.destroyAll(objects, DEV_TRADING_DATA_RESET_DESTROY_OPTIONS);
    return objects.length;
  } catch (err) {
    const code = err && err.code;
    if (code !== 600 && code !== Parse.Error.AGGREGATE_ERROR) {
      throw err;
    }
    let deleted = 0;
    for (const obj of objects) {
      try {
        await obj.destroy(DEV_TRADING_DATA_RESET_DESTROY_OPTIONS);
        deleted += 1;
      } catch (e) {
        const c = e && e.code;
        if (c === 101 || c === Parse.Error.OBJECT_NOT_FOUND) {
          continue;
        }
        throw e;
      }
    }
    return deleted;
  }
}

async function destroyAllInBatches(className, { batchSize = 500 } = {}) {
  const q = new Parse.Query(className);
  q.limit(batchSize);
  let deleted = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const batch = await q.find({ useMasterKey: true });
    if (!batch || batch.length === 0) break;
    const n = await destroyParseObjectsTolerant(batch);
    deleted += n;
    if (n === 0) {
      console.warn(
        `devReset: destroyAllInBatches(${className}): batch of ${batch.length} undeletable — stop (avoid infinite loop).`
      );
      break;
    }
  }

  return deleted;
}

module.exports = {
  envTrue,
  writeDevMaintenanceAudit,
  countAll,
  destroyAllInBatches,
  destroyParseObjectsTolerant,
  DEV_TRADING_DATA_RESET_DESTROY_OPTIONS,
  runWithDevTradingDataResetDestroy,
  isDevTradingDataResetDestroyActive,
};
