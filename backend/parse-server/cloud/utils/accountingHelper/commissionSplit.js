'use strict';

const { round2 } = require('./shared');

/**
 * Splits gross profit into investor-facing total commission and trader/app shares.
 * Investor Collection Bill shows `commission` only (trader + app); trader credit and
 * PLT-REV-COM each receive their respective portion (ADR-010).
 *
 * @param {number} grossProfit
 * @param {{ traderRate: number, appRate: number }} rates
 */
function splitCommissionFromGrossProfit(grossProfit, { traderRate, appRate }) {
  if (!Number.isFinite(grossProfit) || grossProfit <= 0) {
    return {
      commission: 0,
      traderCommission: 0,
      appCommission: 0,
      netProfit: round2(grossProfit || 0),
    };
  }

  const traderCommission = round2(grossProfit * (traderRate || 0));
  const appCommission = round2(grossProfit * (appRate || 0));
  const commission = round2(traderCommission + appCommission);
  const netProfit = round2(grossProfit - commission);

  return { commission, traderCommission, appCommission, netProfit };
}

/**
 * Reads persisted bill metadata (supports legacy bills without app split).
 */
function resolveCommissionPartsFromBillMetadata(meta = {}) {
  const commission = round2(Number(meta.commission) || 0);
  if (Number.isFinite(meta.traderCommission)) {
    const traderCommission = round2(meta.traderCommission);
    const appCommission = Number.isFinite(meta.appCommission)
      ? round2(meta.appCommission)
      : round2(Math.max(0, commission - traderCommission));
    return { commission, traderCommission, appCommission };
  }
  return { commission, traderCommission: commission, appCommission: 0 };
}

module.exports = {
  splitCommissionFromGrossProfit,
  resolveCommissionPartsFromBillMetadata,
};
