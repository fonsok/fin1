'use strict';

const RETRY_KIND = 'trade_settlement';
const RETRY_SCHEDULE_MINUTES = [1, 5, 15, 60, 180, 720];
const DEFAULT_MAX_ATTEMPTS = RETRY_SCHEDULE_MINUTES.length;
const PROCESSING_LEASE_MS = 5 * 60 * 1000;

function nowDate() {
  return new Date();
}

function computeNextRetryAt(attempt) {
  const idx = Math.max(0, Math.min(RETRY_SCHEDULE_MINUTES.length - 1, attempt - 1));
  const minutes = RETRY_SCHEDULE_MINUTES[idx];
  return new Date(Date.now() + (minutes * 60 * 1000));
}

function serializeError(err) {
  if (!err) return 'unknown error';
  return err && err.message ? err.message : String(err);
}

function createLockToken() {
  return `lock_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function isLeaseActive(job) {
  const leaseUntil = job.get('leaseUntil');
  if (!leaseUntil) return false;
  return new Date(leaseUntil).getTime() > Date.now();
}

async function claimSettlementRetryJob(jobId) {
  const current = await new Parse.Query('SettlementRetryJob').get(jobId, { useMasterKey: true });
  const status = String(current.get('status') || 'pending');

  if (status === 'done' || status === 'failed') return null;
  if (status === 'processing' && isLeaseActive(current)) return null;

  const attempts = Number(current.get('attempts') || 0) + 1;
  const maxAttempts = Math.max(1, Number(current.get('maxAttempts') || DEFAULT_MAX_ATTEMPTS));
  const lockToken = createLockToken();

  current.set('status', 'processing');
  current.set('attempts', attempts);
  current.set('startedAt', nowDate());
  current.set('lockToken', lockToken);
  current.set('leaseUntil', new Date(Date.now() + PROCESSING_LEASE_MS));
  await current.save(null, { useMasterKey: true });

  // Re-read to verify claim ownership (last-writer-wins protection across instances).
  const owned = await new Parse.Query('SettlementRetryJob').get(jobId, { useMasterKey: true });
  if (String(owned.get('lockToken') || '') !== lockToken || String(owned.get('status') || '') !== 'processing') {
    return null;
  }

  return {
    job: owned,
    attempts,
    maxAttempts,
    lockToken,
  };
}

async function enqueueSettlementRetry({
  tradeId,
  reason,
  source = 'trade_after_save',
  context = {},
  maxAttempts = DEFAULT_MAX_ATTEMPTS,
}) {
  if (!tradeId) return null;

  const RetryJob = Parse.Object.extend('SettlementRetryJob');

  const existing = await new Parse.Query('SettlementRetryJob')
    .equalTo('kind', RETRY_KIND)
    .equalTo('tradeId', tradeId)
    .containedIn('status', ['pending', 'processing'])
    .descending('updatedAt')
    .first({ useMasterKey: true });

  if (existing) {
    existing.set('lastError', reason || existing.get('lastError') || 'retry requested');
    existing.set('lastSource', source);
    existing.set('lastContext', context || {});
    if (!existing.get('nextRetryAt')) {
      existing.set('nextRetryAt', nowDate());
    }
    await existing.save(null, { useMasterKey: true });
    return existing;
  }

  const job = new RetryJob();
  job.set('kind', RETRY_KIND);
  job.set('tradeId', tradeId);
  job.set('status', 'pending');
  job.set('attempts', 0);
  job.set('maxAttempts', Math.max(1, Number(maxAttempts) || DEFAULT_MAX_ATTEMPTS));
  job.set('nextRetryAt', nowDate());
  job.set('lastError', reason || 'retry requested');
  job.set('lastSource', source);
  job.set('lastContext', context || {});
  await job.save(null, { useMasterKey: true });
  return job;
}

async function processSingleSettlementRetryJob(claimed) {
  const job = claimed.job;
  const attempts = claimed.attempts;
  const maxAttempts = claimed.maxAttempts;
  const lockToken = claimed.lockToken;
  const tradeId = String(job.get('tradeId') || '').trim();

  try {
    if (!tradeId) {
      throw new Error('missing tradeId in retry job');
    }

    const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
    const { settleAndDistribute } = require('./settlement');
    const summary = await settleAndDistribute(trade);

    job.set('status', 'done');
    job.set('completedAt', nowDate());
    job.set('lastError', null);
    job.set('lastSummary', summary || { skipped: true });
    job.unset('lockToken');
    job.unset('leaseUntil');
    await job.save(null, { useMasterKey: true });

    return {
      id: job.id,
      tradeId,
      status: 'done',
      attempts,
      summary: summary || null,
    };
  } catch (err) {
    const terminal = attempts >= maxAttempts;
    job.set('status', terminal ? 'failed' : 'pending');
    job.set('lastError', serializeError(err));
    job.set('failedAt', nowDate());
    if (!terminal) {
      job.set('nextRetryAt', computeNextRetryAt(attempts));
    }
    // Only release lock if we still own the claim.
    const latest = await new Parse.Query('SettlementRetryJob').get(job.id, { useMasterKey: true });
    if (String(latest.get('lockToken') || '') === lockToken) {
      latest.set('status', job.get('status'));
      latest.set('lastError', job.get('lastError'));
      latest.set('failedAt', job.get('failedAt'));
      if (!terminal) latest.set('nextRetryAt', job.get('nextRetryAt'));
      latest.unset('lockToken');
      latest.unset('leaseUntil');
      await latest.save(null, { useMasterKey: true });
    }

    return {
      id: job.id,
      tradeId,
      status: terminal ? 'failed' : 'pending',
      attempts,
      error: serializeError(err),
      nextRetryAt: terminal ? null : job.get('nextRetryAt'),
    };
  }
}

async function processDueSettlementRetries({ limit = 20 } = {}) {
  const effectiveLimit = Math.max(1, Math.min(200, Number(limit) || 20));
  const now = nowDate();

  const pendingJobs = await new Parse.Query('SettlementRetryJob')
    .equalTo('kind', RETRY_KIND)
    .equalTo('status', 'pending')
    .lessThanOrEqualTo('nextRetryAt', now)
    .ascending('nextRetryAt')
    .limit(effectiveLimit * 2)
    .find({ useMasterKey: true });

  const staleProcessingJobs = await new Parse.Query('SettlementRetryJob')
    .equalTo('kind', RETRY_KIND)
    .equalTo('status', 'processing')
    .lessThanOrEqualTo('leaseUntil', now)
    .ascending('updatedAt')
    .limit(effectiveLimit * 2)
    .find({ useMasterKey: true });

  const dueJobs = [...pendingJobs, ...staleProcessingJobs].slice(0, effectiveLimit * 2);

  const results = [];
  for (const job of dueJobs) {
    // eslint-disable-next-line no-await-in-loop
    const claimed = await claimSettlementRetryJob(job.id);
    if (!claimed) continue;
    // eslint-disable-next-line no-await-in-loop
    const result = await processSingleSettlementRetryJob(claimed);
    results.push(result);
    if (results.length >= effectiveLimit) break;
  }

  return {
    processed: results.length,
    results,
  };
}

async function getSettlementRetryQueueStatus({ sampleLimit = 25 } = {}) {
  const counts = {};
  for (const status of ['pending', 'processing', 'failed', 'done']) {
    // eslint-disable-next-line no-await-in-loop
    counts[status] = await new Parse.Query('SettlementRetryJob')
      .equalTo('kind', RETRY_KIND)
      .equalTo('status', status)
      .count({ useMasterKey: true });
  }

  const samples = await new Parse.Query('SettlementRetryJob')
    .equalTo('kind', RETRY_KIND)
    .containedIn('status', ['pending', 'processing', 'failed'])
    .ascending('nextRetryAt')
    .descending('updatedAt')
    .limit(Math.max(1, Math.min(100, Number(sampleLimit) || 25)))
    .find({ useMasterKey: true });

  return {
    kind: RETRY_KIND,
    counts,
    samples: samples.map((row) => ({
      id: row.id,
      tradeId: row.get('tradeId') || null,
      status: row.get('status') || null,
      attempts: Number(row.get('attempts') || 0),
      maxAttempts: Number(row.get('maxAttempts') || DEFAULT_MAX_ATTEMPTS),
      nextRetryAt: row.get('nextRetryAt') ? new Date(row.get('nextRetryAt')).toISOString() : null,
      leaseUntil: row.get('leaseUntil') ? new Date(row.get('leaseUntil')).toISOString() : null,
      lastError: row.get('lastError') || null,
      updatedAt: row.updatedAt ? row.updatedAt.toISOString() : null,
    })),
  };
}

module.exports = {
  enqueueSettlementRetry,
  processDueSettlementRetries,
  getSettlementRetryQueueStatus,
};
