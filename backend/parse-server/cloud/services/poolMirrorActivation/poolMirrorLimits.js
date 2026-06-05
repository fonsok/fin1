'use strict';

/** Max investor splits attached to one mirror trade (abuse / overload guard). */
const DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE = 150;

function readMaxInvestorsPerMirrorTrade() {
  const raw = Number(process.env.POOL_MIRROR_MAX_INVESTORS_PER_TRADE || DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE;
}

module.exports = {
  DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE,
  readMaxInvestorsPerMirrorTrade,
};
