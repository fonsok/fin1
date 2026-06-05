'use strict';

/**
 * Backward-compatible re-exports. SSOT: services/poolMirrorActivation/
 */
const {
  activatePoolMirrorForTrade,
  ensurePoolActivationForLegacyTrade,
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
  resolvePoolActivationDecision,
} = require('../services/poolMirrorActivation/poolMirrorActivationService');
const { normalizeLegType } = require('../services/poolMirrorActivation/poolActivationPolicy');

function shouldSkipPoolActivationForTrade(trade) {
  return normalizeLegType(trade) === 'TRADER';
}

async function ensurePoolActivationForNewTrade(trade) {
  return ensurePoolActivationForLegacyTrade(trade);
}

module.exports = {
  ensurePoolActivationForNewTrade,
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
  shouldSkipPoolActivationForTrade,
  activatePoolMirrorForTrade,
  resolvePoolActivationDecision,
};
