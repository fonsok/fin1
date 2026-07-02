'use strict';

const { peekCacheOrNull } = require('./cache');
const { DEFAULT_CONFIG } = require('./defaultConfig');
const { validateConfigValue } = require('./validateConfigValue');
const { isOverrideEffective } = require('./overrideEffectiveFrom');
const { loadConfig } = require('./loadConfig');

/** Parse `_User` fields for per-trader open depot position limit override. */
const USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS = {
  limit: 'maxOpenDepotPositionsOverride',
  effectiveFrom: 'maxOpenDepotPositionsOverrideEffectiveFrom',
};

const ABSOLUTE_MIN = 1;
const ABSOLUTE_MAX = 50;

function maxFromConfigObject(config) {
  const raw = config?.financial?.maxTraderOpenDepotPositions;
  return normalizeMaxOpenDepotPositions(raw) ?? DEFAULT_CONFIG.financial.maxTraderOpenDepotPositions;
}

async function getMaxTraderOpenDepotPositions() {
  const cached = peekCacheOrNull();
  if (cached) {
    return maxFromConfigObject(cached);
  }
  const config = await loadConfig();
  return maxFromConfigObject(config);
}

function normalizeMaxOpenDepotPositions(raw) {
  const n = Math.floor(Number(raw));
  if (!Number.isFinite(n)) {
    return null;
  }
  const validation = validateConfigValue('maxTraderOpenDepotPositions', n);
  if (!validation.valid) {
    return null;
  }
  return Math.min(ABSOLUTE_MAX, Math.max(ABSOLUTE_MIN, n));
}

/**
 * @param {import('parse').User | null | undefined} user
 * @param {Date} [asOf]
 * @returns {number | null}
 */
function readUserMaxOpenDepotPositionsOverride(user, asOf = new Date()) {
  if (!user) {
    return null;
  }
  if (!isOverrideEffective(user.get(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.effectiveFrom), asOf)) {
    return null;
  }
  return normalizeMaxOpenDepotPositions(user.get(USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit));
}

/**
 * @param {{ traderId?: string, asOf?: Date }} scope
 * @param {{ fetchUser?: (userId: string) => Promise<import('parse').User|null> }} [deps]
 * @returns {Promise<{ limit: number, source: 'global' | 'trader' }>}
 */
async function resolveMaxOpenDepotPositions(scope = {}, deps = {}) {
  const { traderId, asOf = new Date() } = scope;
  const globalLimit = await getMaxTraderOpenDepotPositions();

  const fetchUser = deps.fetchUser || (async (userId) => {
    if (!userId) {
      return null;
    }
    try {
      return await new Parse.Query(Parse.User).get(String(userId), { useMasterKey: true });
    } catch {
      return null;
    }
  });

  if (traderId) {
    const traderUser = await fetchUser(traderId);
    const overrideLimit = readUserMaxOpenDepotPositionsOverride(traderUser, asOf);
    if (overrideLimit !== null) {
      return { limit: overrideLimit, source: 'trader' };
    }
  }

  return { limit: globalLimit, source: 'global' };
}

module.exports = {
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
  ABSOLUTE_MIN,
  ABSOLUTE_MAX,
  getMaxTraderOpenDepotPositions,
  normalizeMaxOpenDepotPositions,
  readUserMaxOpenDepotPositionsOverride,
  resolveMaxOpenDepotPositions,
};
