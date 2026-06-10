'use strict';

const { loadTraderAccountStatementSourceData } = require('./dataLoading');
const { buildTraderCustomerTimelineForUser } = require('./timeline');
const { traderCustomerTimelineToApiRows } = require('./apiRows');
const { parseInstrumentFromTrade } = require('./instruments');

/** Tier 1 — customer API (`getAccountStatement`) + admin user detail loader. */
const tier1CustomerApi = {
  loadTraderAccountStatementSourceData,
  buildTraderCustomerTimelineForUser,
  traderCustomerTimelineToApiRows,
};

/** Tier 2 — Beleg enrichment (admin reports, trader TBC snapshot). */
const tier2BelegEnrichment = {
  parseInstrumentFromTrade,
};

/**
 * Tier 3 — package-internal (import submodule in tests):
 *   TIMELINE_SOURCE_LIMIT, buildTraderCustomerTimeline, buildNetTradeDisplayEvents,
 *   enrichTimelineWithTradeInstruments, parseInstrumentFromInvoice, tradeStatementTitle.
 */

const publicSurface = {
  ...tier1CustomerApi,
  ...tier2BelegEnrichment,
};

const API_TIERS = {
  customerApi: Object.keys(tier1CustomerApi),
  belegEnrichment: Object.keys(tier2BelegEnrichment),
  packageInternal: [
    'TIMELINE_SOURCE_LIMIT',
    'buildTraderCustomerTimeline',
    'buildNetTradeDisplayEvents',
    'enrichTimelineWithTradeInstruments',
    'parseInstrumentFromInvoice',
    'tradeStatementTitle',
  ],
};

module.exports = { publicSurface, API_TIERS };
