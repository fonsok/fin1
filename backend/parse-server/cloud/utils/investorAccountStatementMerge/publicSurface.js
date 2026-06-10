'use strict';

/**
 * Stable public surface for investor account statement merge.
 */

const { syntheticEntryTypeFromLedgerRow } = require('./avaLedger');
const {
  listInvestorInvestmentIds,
  loadInvestorAccountStatementSourceData,
  fetchInvestorEscrowLedgerRows,
} = require('./dataLoading');
const { summarizeClientFundsFromEscrowRows } = require('./clientLiability');
const { buildInvestorMergedTimeline } = require('./mergedTimeline');
const { buildInvestorLedgerGoBTimeline } = require('./ledgerGoBTimeline');
const { applyInvestorGoBCollectionBillFeeGranularity } = require('./collectionBillFeeGranularity');
const {
  mergedTimelineToApiRows,
  mergedTimelineToDescendingApiRows,
} = require('./apiRows');

/** Tier 1 — customer / API use-cases (`getAccountStatement`, app timeline). */
const tier1CustomerUseCases = {
  loadInvestorAccountStatementSourceData,
  buildInvestorMergedTimeline,
  buildInvestorLedgerGoBTimeline,
  mergedTimelineToApiRows,
  mergedTimelineToDescendingApiRows,
};

/** Tier 2 — admin / wallet controls (`getUserDetails`, collection bills). */
const tier2AdminSupport = {
  applyInvestorGoBCollectionBillFeeGranularity,
  summarizeClientFundsFromEscrowRows,
  fetchInvestorEscrowLedgerRows,
  listInvestorInvestmentIds,
  syntheticEntryTypeFromLedgerRow,
};

/**
 * Tier 3 — package-internal (not on facade; import submodule in tests):
 *   signedAmountFromAvaLedgerRow, buildResidualReturnDedupKeys,
 *   isDuplicateAvaResidualLedgerRow, fetchAccountStatementRowsForInvestor,
 *   fetchInvestorAvaCashLedgerRows, timelineRowMatchesEntryType.
 */

const publicSurface = {
  ...tier1CustomerUseCases,
  ...tier2AdminSupport,
};

const API_TIERS = {
  customerUseCases: Object.keys(tier1CustomerUseCases),
  adminSupport: Object.keys(tier2AdminSupport),
  packageInternal: [
    'signedAmountFromAvaLedgerRow',
    'buildResidualReturnDedupKeys',
    'isDuplicateAvaResidualLedgerRow',
    'fetchAccountStatementRowsForInvestor',
    'fetchInvestorAvaCashLedgerRows',
    'timelineRowMatchesEntryType',
  ],
};

module.exports = {
  publicSurface,
  API_TIERS,
};
