'use strict';

/**
 * Report-layer shim — Domain-SSOT: poolMirrorEconomics/tradeLegEconomics.js
 */
const {
  tradeEconomicsSnapshot,
  applyPoolMirrorEconomicsOverrides,
  resolveImmutableBuyInputsForSnapshot,
  extractInstrumentFields,
} = require('../../../utils/poolMirrorEconomics/tradeLegEconomics');
const { round2, round4 } = require('../../../utils/accountingHelper/shared');

module.exports = {
  tradeEconomicsSnapshot,
  applyPoolMirrorEconomicsOverrides,
  resolveImmutableBuyInputsForSnapshot,
  extractInstrumentFields,
  round2,
  round4,
};
