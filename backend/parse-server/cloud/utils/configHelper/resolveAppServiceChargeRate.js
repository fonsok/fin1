'use strict';

const { getAppServiceChargeRateForAccountType } = require('./getters');
const { validateConfigValue } = require('./validateConfigValue');
const { isOverrideEffective } = require('./overrideEffectiveFrom');

/** Parse `_User` fields for per-investor App Service Charge override. */
const USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS = {
  rate: 'appServiceChargeRateOverride',
  effectiveFrom: 'appServiceChargeOverrideEffectiveFrom',
};

function roundRate(n) {
  return Math.round(Number(n) * 10000) / 10000;
}

function normalizeAppServiceChargeRate(raw) {
  const rate = roundRate(raw);
  if (!Number.isFinite(rate)) {
    return null;
  }
  const validation = validateConfigValue('appServiceChargeRate', rate);
  if (!validation.valid) {
    return null;
  }
  return rate;
}

/**
 * @param {import('parse').User | null | undefined} user
 * @param {Date} [asOf]
 * @returns {number | null}
 */
function readUserAppServiceChargeOverride(user, asOf = new Date()) {
  if (!user) {
    return null;
  }
  if (!isOverrideEffective(user.get(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.effectiveFrom), asOf)) {
    return null;
  }
  return normalizeAppServiceChargeRate(user.get(USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate));
}

/**
 * Resolves App Service Charge for an investor: user override > global (by account type).
 *
 * @param {{ investorId?: string, accountType?: string, asOf?: Date }} scope
 * @param {{ fetchUser?: (userId: string) => Promise<import('parse').User|null> }} [deps]
 * @returns {Promise<{ rate: number, source: 'global' | 'investor' }>}
 */
async function resolveAppServiceChargeRate(scope = {}, deps = {}) {
  const { investorId, accountType = 'individual', asOf = new Date() } = scope;
  const globalRate = await getAppServiceChargeRateForAccountType(accountType);

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

  if (investorId) {
    const investorUser = await fetchUser(investorId);
    const overrideRate = readUserAppServiceChargeOverride(investorUser, asOf);
    if (overrideRate !== null) {
      return { rate: overrideRate, source: 'investor' };
    }
  }

  return { rate: globalRate, source: 'global' };
}

/**
 * Cached resolver for batch operations.
 *
 * @param {{ asOf?: Date, fetchUser?: (userId: string) => Promise<import('parse').User|null> }} [options]
 */
async function createAppServiceChargeResolver(options = {}) {
  const { asOf = new Date(), fetchUser: fetchUserInjected } = options;
  const userCache = new Map();

  const fetchUser = async (userId) => {
    if (!userId) {
      return null;
    }
    const key = String(userId);
    if (userCache.has(key)) {
      return userCache.get(key);
    }
    let user = null;
    if (fetchUserInjected) {
      user = await fetchUserInjected(key);
    } else {
      try {
        user = await new Parse.Query(Parse.User).get(key, { useMasterKey: true });
      } catch {
        user = null;
      }
    }
    userCache.set(key, user);
    return user;
  };

  return {
    resolve({ investorId, accountType }) {
      return resolveAppServiceChargeRate(
        { investorId, accountType, asOf },
        { fetchUser },
      );
    },
  };
}

module.exports = {
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  normalizeAppServiceChargeRate,
  readUserAppServiceChargeOverride,
  resolveAppServiceChargeRate,
  createAppServiceChargeResolver,
};
