'use strict';

/**
 * GoB: Gebührenbasis für Investor-Mirror-Legs ist zum Zeitpunkt der Reservierung
 * eingefroren (`Investment.feeConfigSnapshot`). Spätere Änderungen an `Configuration.financial`
 * dürfen laufende Investments nicht verfälschen. `trade.feeConfig` bleibt optionaler Override.
 *
 * @param {Parse.Object|null|undefined} investment
 * @param {Parse.Object|null|undefined} trade
 * @param {object} liveFinancial — typisch `loadConfig().financial`
 * @returns {object} flaches Objekt für `calculateOrderFees` / `computeInvestorBuyLeg`
 */
function mergeInvestorFeeConfig(investment, trade, liveFinancial = {}) {
  const base = typeof liveFinancial === 'object' && liveFinancial !== null ? liveFinancial : {};
  const tradeOverrides = trade && typeof trade.get === 'function' ? (trade.get('feeConfig') || {}) : {};
  const tradeObj = typeof tradeOverrides === 'object' && tradeOverrides !== null && !Array.isArray(tradeOverrides)
    ? tradeOverrides
    : {};

  const snap = investment && typeof investment.get === 'function' ? investment.get('feeConfigSnapshot') : null;
  const snapObj = snap && typeof snap === 'object' && !Array.isArray(snap) ? snap : null;
  if (snapObj && Object.keys(snapObj).length > 0) {
    return { ...snapObj, ...tradeObj };
  }
  return { ...base, ...tradeObj };
}

module.exports = {
  mergeInvestorFeeConfig,
};
