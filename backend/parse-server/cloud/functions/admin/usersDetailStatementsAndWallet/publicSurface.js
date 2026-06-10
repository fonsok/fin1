'use strict';

const { loadAccountStatementAndWalletControls } = require('./loadAccountStatementAndWalletControls');

/** Tier 1 — primary admin use-case (`getUserDetails`). */
const tier1AdminUseCase = {
  loadAccountStatementAndWalletControls,
};

/**
 * Tier 2 — package-internal mappers (import submodule in tests):
 *   buildLedgerAccountStatementFromStmtEntries,
 *   mapTraderTimelineToAdminEntries, mapInvestorTimelineToAdminEntries,
 *   mapInvestorCollectionBillDocumentToSummary.
 */

const publicSurface = { ...tier1AdminUseCase };

const API_TIERS = {
  adminUseCase: Object.keys(tier1AdminUseCase),
  packageInternal: [
    'buildLedgerAccountStatementFromStmtEntries',
    'mapTraderTimelineToAdminEntries',
    'mapInvestorTimelineToAdminEntries',
    'mapInvestorCollectionBillDocumentToSummary',
  ],
};

module.exports = { publicSurface, API_TIERS };
