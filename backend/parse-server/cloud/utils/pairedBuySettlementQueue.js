'use strict';

const { getRedisClient, isRedisConfigured } = require('./redisClient');
const { withDistributedSemaphore, getSemaphoreStats, semaphoreBusyError } = require('./distributedSemaphore');
const { verifyPairedBuySettlement } = require('./pairedBuyOrchestration');

const DEFAULT_FINALIZE_MAX = 4;
const DEFAULT_LOCK_TTL_SEC = 180;
const DEFAULT_MAX_WAIT_MS = 120_000;

const inMemoryPairChains = new Map();

function readFinalizeMaxConcurrent() {
  const raw = Number(process.env.PAIRED_BUY_FINALIZE_MAX_CONCURRENT || DEFAULT_FINALIZE_MAX);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_FINALIZE_MAX;
}

function readMaxWaitMs() {
  const raw = Number(process.env.PAIRED_BUY_SETTLEMENT_MAX_WAIT_MS || DEFAULT_MAX_WAIT_MS);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_MAX_WAIT_MS;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForPeerSettlement(pairExecutionId, maxWaitMs) {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    const check = await verifyPairedBuySettlement(pairExecutionId);
    if (check.ok) return true;
    await sleep(400);
  }
  return false;
}

function runInMemoryPairExclusive(pairExecutionId, fn) {
  const prev = inMemoryPairChains.get(pairExecutionId) || Promise.resolve();
  const run = prev
    .catch(() => {})
    .then(() => fn());
  const tail = run.catch(() => {});
  inMemoryPairChains.set(pairExecutionId, tail);
  return run.finally(() => {
    if (inMemoryPairChains.get(pairExecutionId) === tail) {
      inMemoryPairChains.delete(pairExecutionId);
    }
  });
}

async function withRedisPairLock(pairExecutionId, fn, maxWaitMs) {
  const redis = await getRedisClient();
  if (!redis) {
    return runInMemoryPairExclusive(pairExecutionId, fn);
  }

  const lockKey = `fin1:paired:settle:lock:${pairExecutionId}`;
  const token = `${process.pid || 'p'}:${Date.now()}:${Math.random().toString(36).slice(2)}`;
  const ttl = Number(process.env.PAIRED_BUY_SETTLEMENT_LOCK_TTL_SEC || DEFAULT_LOCK_TTL_SEC);
  const deadline = Date.now() + maxWaitMs;

  while (Date.now() < deadline) {
    const acquired = await redis.set(lockKey, token, { NX: true, EX: ttl });
    if (acquired) {
      try {
        return await fn();
      } finally {
        const current = await redis.get(lockKey);
        if (current === token) {
          await redis.del(lockKey);
        }
      }
    }

    if (await waitForPeerSettlement(pairExecutionId, Math.min(5000, deadline - Date.now()))) {
      return { peerCompleted: true };
    }
    await sleep(250 + Math.floor(Math.random() * 150));
  }

  throw semaphoreBusyError('Paired buy settlement');
}

/**
 * Global settlement queue: one finalize per pairExecutionId cluster-wide; capped concurrent finalizes.
 * @template T
 * @param {string} pairExecutionId
 * @param {() => Promise<T>} worker
 * @returns {Promise<T|{ peerCompleted: true }>}
 */
async function runPairedBuySettlement(pairExecutionId, worker) {
  const pairId = String(pairExecutionId || '').trim();
  if (!pairId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'pairExecutionId required');
  }

  const maxWaitMs = readMaxWaitMs();
  const maxConcurrent = readFinalizeMaxConcurrent();

  return withRedisPairLock(pairId, async () => {
    const outcome = await withDistributedSemaphore(
      'paired_buy_finalize',
      { maxConcurrent, maxWaitMs, ttlSeconds: 300 },
      worker,
    );
    return outcome;
  }, maxWaitMs);
}

async function getPairedBuySettlementQueueStats() {
  const redis = await getRedisClient();
  const finalize = await getSemaphoreStats('paired_buy_finalize', readFinalizeMaxConcurrent());
  let lockSampleCount = null;
  if (redis) {
    try {
      const keys = await redis.keys('fin1:paired:settle:lock:*');
      lockSampleCount = Array.isArray(keys) ? keys.length : 0;
    } catch (_) {
      lockSampleCount = null;
    }
  }

  return {
    mode: redis ? 'redis' : 'in_process',
    redisConfigured: isRedisConfigured(),
    finalizeMaxConcurrent: readFinalizeMaxConcurrent(),
    maxWaitMs: readMaxWaitMs(),
    finalize,
    inFlightPairLocks: lockSampleCount ?? inMemoryPairChains.size,
  };
}

module.exports = {
  runPairedBuySettlement,
  getPairedBuySettlementQueueStats,
  readFinalizeMaxConcurrent,
  waitForPeerSettlement,
};
