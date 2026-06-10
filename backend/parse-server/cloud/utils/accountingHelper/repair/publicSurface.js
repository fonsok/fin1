'use strict';

const { repairTradeSettlement } = require('./repairTradeSettlement');

/** Tier 1 — admin-only destructive repair use-case. */
const tier1RepairUseCase = {
  repairTradeSettlement,
};

const publicSurface = { ...tier1RepairUseCase };

const API_TIERS = {
  repairUseCase: Object.keys(tier1RepairUseCase),
  packageInternal: [
    'findBackendDocumentsForTrades',
    'findBackendStatementsForTrades',
    'destroyAllInBatches',
    'resetParticipation',
  ],
};

module.exports = { publicSurface, API_TIERS };
