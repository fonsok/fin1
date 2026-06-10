'use strict';

const {
  mirrorPoolTradeHasSyncedExitEconomics,
  getTraderTradeForPairedMirrorLeg,
  getMirrorTradeForPairedTraderLeg,
  isPairedTraderLegTrade,
} = require('./legResolution');
const {
  syncMirrorTradeWhenTraderLegCompletes,
  syncMirrorPoolSellProgressFromTraderLeg,
} = require('./sellSync');

/** Tier 1 — trigger/orchestration use-cases. */
const tier1SyncUseCases = {
  syncMirrorTradeWhenTraderLegCompletes,
  syncMirrorPoolSellProgressFromTraderLeg,
};

/** Tier 2 — settlement/repair leg resolution + idempotency probes. */
const tier2LegResolution = {
  mirrorPoolTradeHasSyncedExitEconomics,
  isPairedTraderLegTrade,
  getMirrorTradeForPairedTraderLeg,
  getTraderTradeForPairedMirrorLeg,
};

/**
 * Package-internal: `sellSync.applyMirrorSellSyncFromTraderLeg` (tests read submodule).
 */

const publicSurface = {
  ...tier1SyncUseCases,
  ...tier2LegResolution,
};

const API_TIERS = {
  syncUseCases: Object.keys(tier1SyncUseCases),
  legResolution: Object.keys(tier2LegResolution),
  packageInternal: ['applyMirrorSellSyncFromTraderLeg'],
};

module.exports = { publicSurface, API_TIERS };
