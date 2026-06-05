'use strict';

/**
 * Single technical person key: Parse `_User.objectId`.
 * Legacy `user:email@test.com` is resolved on write and eligible for backfill.
 */

const PARSE_OBJECT_ID_RE = /^[a-zA-Z0-9]{10}$/;

function looksLikeParseObjectId(value) {
  return typeof value === 'string' && PARSE_OBJECT_ID_RE.test(value.trim());
}

function isLegacyStableUserId(value) {
  const s = String(value || '').trim();
  return s.startsWith('user:') && s.includes('@');
}

function emailFromLegacyStableUserId(value) {
  const s = String(value || '').trim();
  if (!isLegacyStableUserId(s)) return '';
  return s.slice(5).toLowerCase();
}

/**
 * In-process cache: legacy key or email → Parse objectId.
 * @type {Map<string, string>}
 */
const resolveCache = new Map();

function cacheKey(raw) {
  return String(raw || '').trim().toLowerCase();
}

/**
 * Resolve any stored user reference to Parse `_User.objectId`.
 * @param {string} raw
 * @param {{ useCache?: boolean }} [opts]
 * @returns {Promise<string>} canonical objectId, or trimmed raw if unresolvable
 */
async function resolveCanonicalUserId(raw, opts = {}) {
  const useCache = opts.useCache !== false;
  const trimmed = String(raw || '').trim();
  if (!trimmed) return '';
  if (looksLikeParseObjectId(trimmed)) return trimmed;

  const key = cacheKey(trimmed);
  if (useCache && resolveCache.has(key)) {
    return resolveCache.get(key);
  }

  let email = '';
  if (isLegacyStableUserId(trimmed)) {
    email = emailFromLegacyStableUserId(trimmed);
  } else if (trimmed.includes('@')) {
    email = trimmed.toLowerCase();
  }

  if (email) {
    const q = new Parse.Query(Parse.User);
    q.equalTo('email', email);
    const user = await q.first({ useMasterKey: true });
    if (user && user.id) {
      if (useCache) {
        resolveCache.set(key, user.id);
        resolveCache.set(cacheKey(user.id), user.id);
        resolveCache.set(cacheKey(`user:${email}`), user.id);
      }
      return user.id;
    }
  }

  // Last resort: treat as objectId lookup (may throw)
  if (!trimmed.startsWith('user:')) {
    try {
      const byId = await new Parse.Query(Parse.User).get(trimmed, { useMasterKey: true });
      if (byId && byId.id) {
        if (useCache) resolveCache.set(key, byId.id);
        return byId.id;
      }
    } catch {
      // not a valid objectId
    }
  }

  return trimmed;
}

/**
 * Session-scoped read keys: canonical id only, plus legacy alias while data may still carry `user:email`.
 * @param {Parse.User} user
 * @returns {string[]}
 */
function collectLedgerUserIdCandidates(user) {
  if (!user || typeof user.get !== 'function' || !user.id) {
    return [];
  }
  const keys = new Set();
  keys.add(String(user.id));
  const stable = String(user.get('stableId') || '').trim();
  if (stable && stable !== user.id) {
    keys.add(stable);
  }
  const email = String(user.get('email') || '').toLowerCase().trim();
  if (email) {
    keys.add(`user:${email}`);
  }
  return Array.from(keys).filter(Boolean);
}

/**
 * SSOT for new writes: always Parse objectId (never synthesize `user:email`).
 * @param {Parse.User} user
 * @returns {string}
 */
function getCanonicalUserId(user) {
  if (!user || !user.id) return '';
  return String(user.id);
}

/** @deprecated Use getCanonicalUserId — returns objectId, not `user:email`. */
function getUserStableId(user) {
  return getCanonicalUserId(user);
}

function clearCanonicalUserIdCache() {
  resolveCache.clear();
}

module.exports = {
  looksLikeParseObjectId,
  isLegacyStableUserId,
  emailFromLegacyStableUserId,
  resolveCanonicalUserId,
  collectLedgerUserIdCandidates,
  getCanonicalUserId,
  getUserStableId,
  clearCanonicalUserIdCache,
};
