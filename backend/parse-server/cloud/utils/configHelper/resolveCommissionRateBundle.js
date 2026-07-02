'use strict';

const { getCommissionRateBundle } = require('./getters');
const {
  normalizeCommissionRateBundle,
  validateCommissionRateBundle,
  bundleToSettlementRates,
} = require('./commissionRateBundle');
const { readInvestmentCommissionRateSnapshot } = require('../accountingHelper/commissionRateSnapshot');
const { isOverrideEffective } = require('./overrideEffectiveFrom');

/** Parse `_User` fields for per-user commission overrides (Phase 1 — backend only). */
const USER_COMMISSION_OVERRIDE_FIELDS = {
  bundle: 'commissionRateBundleOverride',
  role: 'commissionRateOverrideRole',
  effectiveFrom: 'commissionRateOverrideEffectiveFrom',
};

const COMMISSION_OVERRIDE_ROLES = new Set(['trader', 'investor']);

function normalizeCommissionOverrideRole(rawRole) {
  if (typeof rawRole === 'string' && COMMISSION_OVERRIDE_ROLES.has(rawRole)) {
    return rawRole;
  }
  return null;
}

/**
 * Reads a validated commission bundle override from a Parse User, scoped by role.
 *
 * @param {import('parse').User | null | undefined} user
 * @param {'trader' | 'investor'} expectedRole
 * @param {Date} [asOf]
 * @returns {{ bundle: object, role: string } | null}
 */
function readUserCommissionRateOverride(user, expectedRole, asOf = new Date()) {
  if (!user) {
    return null;
  }

  const role = normalizeCommissionOverrideRole(user.get(USER_COMMISSION_OVERRIDE_FIELDS.role));
  if (role && role !== expectedRole) {
    return null;
  }

  if (!isOverrideEffective(user.get(USER_COMMISSION_OVERRIDE_FIELDS.effectiveFrom), asOf)) {
    return null;
  }

  const validation = validateCommissionRateBundle(user.get(USER_COMMISSION_OVERRIDE_FIELDS.bundle));
  if (!validation.valid || !validation.bundle) {
    return null;
  }

  return {
    bundle: validation.bundle,
    role: role || expectedRole,
  };
}

/**
 * Resolves commission rates: investment snapshot > investor override > trader override > global.
 *
 * @param {{ traderId?: string, investorId?: string, investment?: Parse.Object, asOf?: Date }} scope
 * @param {{ fetchUser?: (userId: string) => Promise<import('parse').User|null> }} [deps]
 * @returns {Promise<{
 *   traderRate: number,
 *   appRate: number,
 *   totalRate: number,
 *   source: 'global' | 'investor' | 'trader' | 'investment_snapshot',
 *   bundle: object | null,
 * }>}
 */
async function resolveCommissionRateBundle(scope = {}, deps = {}) {
  const { traderId, investorId, investment, asOf = new Date() } = scope;
  const globalRates = await getCommissionRateBundle();

  const snapshotRates = readInvestmentCommissionRateSnapshot(investment);
  if (snapshotRates) {
    return snapshotRates;
  }

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
    const investorOverride = readUserCommissionRateOverride(investorUser, 'investor', asOf);
    if (investorOverride) {
      return {
        ...bundleToSettlementRates(investorOverride.bundle),
        source: 'investor',
        bundle: investorOverride.bundle,
      };
    }
  }

  if (traderId) {
    const traderUser = await fetchUser(traderId);
    const traderOverride = readUserCommissionRateOverride(traderUser, 'trader', asOf);
    if (traderOverride) {
      return {
        ...bundleToSettlementRates(traderOverride.bundle),
        source: 'trader',
        bundle: traderOverride.bundle,
      };
    }
  }

  return {
    ...globalRates,
    source: 'global',
    bundle: null,
  };
}

/**
 * Cached resolver for batch settlement (avoids repeated Parse user fetches).
 *
 * @param {{ asOf?: Date, fetchUser?: (userId: string) => Promise<import('parse').User|null> }} [options]
 */
async function createCommissionRateResolver(options = {}) {
  const { asOf = new Date(), fetchUser: fetchUserInjected } = options;
  const globalRates = await getCommissionRateBundle();
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

  async function resolve({ traderId, investorId, investment }) {
    const snapshotRates = readInvestmentCommissionRateSnapshot(investment);
    if (snapshotRates) {
      return snapshotRates;
    }

    if (investorId) {
      const investorUser = await fetchUser(investorId);
      const investorOverride = readUserCommissionRateOverride(investorUser, 'investor', asOf);
      if (investorOverride) {
        return {
          ...bundleToSettlementRates(investorOverride.bundle),
          source: 'investor',
          bundle: investorOverride.bundle,
        };
      }
    }

    if (traderId) {
      const traderUser = await fetchUser(traderId);
      const traderOverride = readUserCommissionRateOverride(traderUser, 'trader', asOf);
      if (traderOverride) {
        return {
          ...bundleToSettlementRates(traderOverride.bundle),
          source: 'trader',
          bundle: traderOverride.bundle,
        };
      }
    }

    return {
      ...globalRates,
      source: 'global',
      bundle: null,
    };
  }

  return { resolve, globalRates };
}

/**
 * Effective rate for document snapshots when participations used mixed rates.
 *
 * @param {number} amount
 * @param {number} basis
 * @param {number} fallbackRate
 */
function effectiveCommissionRateFromAmount(amount, basis, fallbackRate) {
  if (Number.isFinite(amount) && Number.isFinite(basis) && basis > 0 && amount > 0) {
    return Math.round((amount / basis) * 10000) / 10000;
  }
  return fallbackRate;
}

module.exports = {
  USER_COMMISSION_OVERRIDE_FIELDS,
  COMMISSION_OVERRIDE_ROLES,
  normalizeCommissionOverrideRole,
  readUserCommissionRateOverride,
  resolveCommissionRateBundle,
  createCommissionRateResolver,
  effectiveCommissionRateFromAmount,
};
