'use strict';

const {
  validateCommissionRateBundle,
  bundleToSettlementRates,
} = require('../configHelper/commissionRateBundle');

/**
 * GoB: Provisions-Bundle zum Reservierungszeitpunkt eingefroren (`Investment.commissionRateBundleSnapshot`).
 * Settlement und Teil-Verkäufe lesen diesen Snapshot vor Live-Overrides/Global-Config.
 *
 * @param {Parse.Object|null|undefined} investment
 * @returns {{
 *   traderRate: number,
 *   appRate: number,
 *   totalRate: number,
 *   source: 'investment_snapshot',
 *   bundle: object,
 * } | null}
 */
function readInvestmentCommissionRateSnapshot(investment) {
  const raw = investment && typeof investment.get === 'function'
    ? investment.get('commissionRateBundleSnapshot')
    : null;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }

  const validation = validateCommissionRateBundle({
    investorCommissionRateTotal: raw.investorCommissionRateTotal,
    traderCommissionRate: raw.traderCommissionRate,
    appCommissionRate: raw.appCommissionRate,
  });
  if (!validation.valid || !validation.bundle) {
    return null;
  }

  return {
    ...bundleToSettlementRates(validation.bundle),
    source: 'investment_snapshot',
    bundle: validation.bundle,
  };
}

module.exports = {
  readInvestmentCommissionRateSnapshot,
};
