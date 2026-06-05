'use strict';

/** Lazy singleton Redis client for Parse Cloud (uses REDIS_URL from production compose). */
let client = null;
let connectPromise = null;
let connectFailed = false;

function isRedisConfigured() {
  return Boolean(String(process.env.REDIS_URL || '').trim());
}

async function getRedisClient() {
  if (!isRedisConfigured() || connectFailed) return null;
  if (client?.isOpen) return client;

  if (!connectPromise) {
    connectPromise = (async () => {
      try {
        const { createClient } = require('redis');
        const next = createClient({ url: process.env.REDIS_URL });
        next.on('error', (err) => {
          console.error('redisClient: connection error', err?.message || err);
        });
        await next.connect();
        client = next;
        return next;
      } catch (err) {
        connectFailed = true;
        console.warn('redisClient: unavailable, using in-process fallbacks —', err?.message || err);
        return null;
      }
    })();
  }

  return connectPromise;
}

function resetRedisClientForTests() {
  client = null;
  connectPromise = null;
  connectFailed = false;
}

module.exports = {
  isRedisConfigured,
  getRedisClient,
  resetRedisClientForTests,
};
