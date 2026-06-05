'use strict';

const { audit } = require('../structuredLogger');
const { processDueSettlementRetries } = require('./retryQueue');

const RETRY_KIND = 'trade_settlement';
const ORPHAN_STATUSES = ['pending', 'processing', 'failed'];

/** Errors that may succeed after a code fix — safe to requeue when trade still exists. */
const RECOVERABLE_ERROR_PATTERNS = [
  /findExistingStatementEntry is not defined/i,
  /is not a function/i,
  /Cannot read propert/i,
];

function isRecoverableError(message) {
  const msg = String(message || '').trim();
  if (!msg) return false;
  return RECOVERABLE_ERROR_PATTERNS.some((re) => re.test(msg));
}

function isTradeNotFoundError(message) {
  return /object not found/i.test(String(message || ''));
}

async function tradeExists(tradeId) {
  if (!tradeId) return false;
  try {
    await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
    return true;
  } catch (_) {
    return false;
  }
}

/**
 * Reconcile stale SettlementRetryJob rows (orphan trades, recoverable code errors).
 * @param {{ dryRun?: boolean, limit?: number, requeueRecoverable?: boolean, runQueueAfter?: boolean }} opts
 */
async function reconcileStaleSettlementRetryJobs({
  dryRun = true,
  limit = 100,
  requeueRecoverable = true,
  runQueueAfter = false,
} = {}) {
  const cap = Math.max(1, Math.min(500, Number(limit) || 100));

  const jobs = await new Parse.Query('SettlementRetryJob')
    .equalTo('kind', RETRY_KIND)
    .containedIn('status', ORPHAN_STATUSES)
    .descending('updatedAt')
    .limit(cap)
    .find({ useMasterKey: true });

  const actions = [];
  let cancelledOrphan = 0;
  let requeued = 0;
  let skipped = 0;

  for (const job of jobs) {
    const tradeId = String(job.get('tradeId') || '').trim();
    const status = String(job.get('status') || '');
    const lastError = String(job.get('lastError') || '').trim();
    const exists = await tradeExists(tradeId);

    if (!exists) {
      actions.push({
        jobId: job.id,
        tradeId,
        action: 'cancel_orphan',
        previousStatus: status,
        lastError: lastError || null,
      });
      if (!dryRun) {
        job.set('status', 'cancelled');
        job.set('lastError', 'trade_not_found');
        job.set('cancelledAt', new Date());
        job.unset('lockToken');
        job.unset('leaseUntil');
        await job.save(null, { useMasterKey: true });
      }
      cancelledOrphan += 1;
      continue;
    }

    if (requeueRecoverable && isRecoverableError(lastError)) {
      actions.push({
        jobId: job.id,
        tradeId,
        action: 'requeue_recoverable',
        previousStatus: status,
        lastError,
      });
      if (!dryRun) {
        job.set('status', 'pending');
        job.set('nextRetryAt', new Date());
        job.set('lastError', null);
        job.unset('lockToken');
        job.unset('leaseUntil');
        job.unset('failedAt');
        await job.save(null, { useMasterKey: true });
      }
      requeued += 1;
      continue;
    }

    if (status === 'failed' && isTradeNotFoundError(lastError)) {
      actions.push({
        jobId: job.id,
        tradeId,
        action: 'cancel_orphan_error',
        previousStatus: status,
        lastError,
      });
      if (!dryRun) {
        job.set('status', 'cancelled');
        job.set('lastError', 'trade_not_found');
        job.set('cancelledAt', new Date());
        await job.save(null, { useMasterKey: true });
      }
      cancelledOrphan += 1;
      continue;
    }

    skipped += 1;
  }

  let queueResult = null;
  if (!dryRun && runQueueAfter && (requeued > 0 || cancelledOrphan > 0)) {
    queueResult = await processDueSettlementRetries({ limit: 25 });
  }

  audit.info('settlement.retry.reconcile', {
    dryRun,
    scanned: jobs.length,
    cancelledOrphan,
    requeued,
    skipped,
    runQueueAfter,
    processed: queueResult?.processed || 0,
  });

  return {
    dryRun,
    scanned: jobs.length,
    cancelledOrphan,
    requeued,
    skipped,
    actions: actions.slice(0, 50),
    queueResult,
  };
}

module.exports = {
  reconcileStaleSettlementRetryJobs,
  isRecoverableError,
  isTradeNotFoundError,
};
