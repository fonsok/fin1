'use strict';

const CACHE_TTL_MS = 5 * 60 * 1000;

let configCache = null;
let cacheTimestamp = 0;

function invalidateCache() {
  configCache = null;
  cacheTimestamp = 0;
}

function getCachedConfig(now, forceRefresh) {
  if (!forceRefresh && configCache && (now - cacheTimestamp) < CACHE_TTL_MS) {
    return configCache;
  }
  return null;
}

function setCachedConfig(data, now) {
  configCache = data;
  cacheTimestamp = now;
}

function peekCacheOrNull() {
  return configCache;
}

module.exports = {
  CACHE_TTL_MS,
  invalidateCache,
  getCachedConfig,
  setCachedConfig,
  peekCacheOrNull,
};
