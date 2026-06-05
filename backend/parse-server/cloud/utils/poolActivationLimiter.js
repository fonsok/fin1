'use strict';

const { withDistributedSemaphore, getSemaphoreStats } = require('./distributedSemaphore');

/**
 * Limits concurrent pool-mirror activations (Redis cluster-wide when REDIS_URL set).
 */
const DEFAULT_MAX_CONCURRENT = 6;
const SEMAPHORE_NAME = 'pool_mirror_activation';

function readMaxConcurrent() {
  const raw = Number(process.env.POOL_MIRROR_MAX_CONCURRENT_ACTIVATIONS || DEFAULT_MAX_CONCURRENT);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_MAX_CONCURRENT;
}

/**
 * @template T
 * @param {() => Promise<T>} fn
 * @returns {Promise<T>}
 */
async function withPoolActivationConcurrencyLimit(fn) {
  const max = readMaxConcurrent();
  const maxWaitMs = Number(process.env.POOL_MIRROR_SEMAPHORE_MAX_WAIT_MS || 120_000);
  return withDistributedSemaphore(
    SEMAPHORE_NAME,
    { maxConcurrent: max, maxWaitMs },
    fn,
  );
}

async function getPoolActivationLimiterStats() {
  return getSemaphoreStats(SEMAPHORE_NAME, readMaxConcurrent());
}

module.exports = {
  withPoolActivationConcurrencyLimit,
  getPoolActivationLimiterStats,
  readMaxConcurrent,
};
