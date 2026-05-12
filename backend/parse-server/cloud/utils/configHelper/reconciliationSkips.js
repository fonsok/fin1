'use strict';

/**
 * Financial keys omitted from `reconcileConfigDefaults` (DEFAULT_CONFIG.financial vs `loadConfig` DB).
 *
 * Rationale: these values are **governance-owned** (Admin Portal / 4-eyes or seed scripts). The
 * cold-start defaults in `defaultConfig.js` exist only for empty DB / bootstrap. Persisted
 * Configuration is authoritative at runtime (`loadConfig`). A mismatch is therefore **expected**
 * in normal operation — not a useful regression signal in server logs.
 *
 * **Not** skipped: order/exchange/foreign fee fields and `minimumCashReserve` — deploys that
 * change fee defaults should still surface as drift until the DB row is aligned (operational visibility).
 */
const FINANCIAL_RECONCILIATION_SKIP_KEYS = Object.freeze(new Set([
  'initialAccountBalance',
  'traderCommissionRate',
  'appServiceChargeRate',
  'appServiceChargeRateCompanies',
]));

module.exports = {
  FINANCIAL_RECONCILIATION_SKIP_KEYS,
};
