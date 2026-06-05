'use strict';

const { getRedisClient, isRedisConfigured } = require('./redisClient');

const ACQUIRE_LUA = `
local current = tonumber(redis.call('GET', KEYS[1]) or '0')
local max = tonumber(ARGV[1])
if current < max then
  redis.call('INCR', KEYS[1])
  redis.call('EXPIRE', KEYS[1], tonumber(ARGV[2]))
  return 1
end
return 0
`;

const RELEASE_LUA = `
local v = tonumber(redis.call('GET', KEYS[1]) or '0')
if v <= 1 then
  redis.call('DEL', KEYS[1])
  return 0
end
return redis.call('DECR', KEYS[1])
`;

const inProcessByName = new Map();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getInProcessState(name) {
  if (!inProcessByName.has(name)) {
    inProcessByName.set(name, { active: 0, waitQueue: [] });
  }
  return inProcessByName.get(name);
}

async function acquireInProcess(name, maxConcurrent, maxWaitMs) {
  const state = getInProcessState(name);
  const deadline = Date.now() + maxWaitMs;

  while (Date.now() < deadline) {
    if (state.active < maxConcurrent) {
      state.active += 1;
      return () => {
        state.active = Math.max(0, state.active - 1);
        const next = state.waitQueue.shift();
        if (next) next();
      };
    }
    await new Promise((resolve) => {
      state.waitQueue.push(resolve);
    });
  }

  const err = new Error(`Semaphore ${name} busy after ${maxWaitMs}ms`);
  err.code = 'SEMAPHORE_TIMEOUT';
  throw err;
}

async function acquireRedis(name, maxConcurrent, ttlSeconds, maxWaitMs) {
  const redis = await getRedisClient();
  if (!redis) {
    return acquireInProcess(name, maxConcurrent, maxWaitMs);
  }

  const key = `fin1:sem:${name}:active`;
  const deadline = Date.now() + maxWaitMs;

  while (Date.now() < deadline) {
    const acquired = await redis.eval(ACQUIRE_LUA, {
      keys: [key],
      arguments: [String(maxConcurrent), String(ttlSeconds)],
    });
    if (acquired === 1) {
      return async () => {
        await redis.eval(RELEASE_LUA, { keys: [key], arguments: [] });
      };
    }
    await sleep(200 + Math.floor(Math.random() * 200));
  }

  const err = new Error(`Redis semaphore ${name} busy after ${maxWaitMs}ms`);
  err.code = 'SEMAPHORE_TIMEOUT';
  throw err;
}

/**
 * @param {string} name
 * @param {object} options
 * @param {number} options.maxConcurrent
 * @param {number} [options.maxWaitMs]
 * @param {number} [options.ttlSeconds] Redis key TTL safety
 * @param {() => Promise<T>} fn
 * @returns {Promise<T>}
 * @template T
 */
async function withDistributedSemaphore(name, options, fn) {
  const maxConcurrent = options.maxConcurrent;
  const maxWaitMs = options.maxWaitMs ?? 120_000;
  const ttlSeconds = options.ttlSeconds ?? 300;

  let release;
  try {
    release = await acquireRedis(name, maxConcurrent, ttlSeconds, maxWaitMs);
    return await fn();
  } finally {
    if (release) await release();
  }
}

function getInProcessSemaphoreStats(name) {
  const state = inProcessByName.get(name);
  if (!state) {
    return { active: 0, queued: 0 };
  }
  return { active: state.active, queued: state.waitQueue.length };
}

async function getSemaphoreStats(name, maxConcurrent) {
  const redis = await getRedisClient();
  if (!redis) {
    return {
      backend: 'in_process',
      active: getInProcessSemaphoreStats(name).active,
      queued: getInProcessSemaphoreStats(name).queued,
      maxConcurrent,
    };
  }

  const key = `fin1:sem:${name}:active`;
  const raw = await redis.get(key);
  const active = Number(raw || 0);
  return {
    backend: 'redis',
    active: Number.isFinite(active) ? active : 0,
    queued: getInProcessSemaphoreStats(name).queued,
    maxConcurrent,
    redisConfigured: isRedisConfigured(),
  };
}

function semaphoreBusyError(label) {
  return new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    `${label} — server busy, retry shortly`,
  );
}

module.exports = {
  withDistributedSemaphore,
  getSemaphoreStats,
  getInProcessSemaphoreStats,
  semaphoreBusyError,
  acquireInProcess,
};
