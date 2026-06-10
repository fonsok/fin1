'use strict';

const {
  TRADER_COLLECTION_BILL_SCHEMA_VERSION,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
} = require('./shared');
const { buildTraderCollectionBillBelegSnapshot } = require('./buildCollectionBill');
const { buildTradingFeesBelegSnapshot } = require('./tradingFeesBeleg');
const { formatTraderCollectionBillSummaryText } = require('./summaryText');
const { traderCollectionBillDisplaySections } = require('./displaySections');

/** Tier 1 — Beleg snapshot build + admin presentation. */
const tier1BelegSnapshots = {
  buildTraderCollectionBillBelegSnapshot,
  buildTradingFeesBelegSnapshot,
  formatTraderCollectionBillSummaryText,
  traderCollectionBillDisplaySections,
};

/** Tier 2 — backfill / enrichment helpers. */
const tier2BackfillSupport = {
  TRADER_COLLECTION_BILL_SCHEMA_VERSION,
  isUsableTraderBelegSummaryText,
  metadataNeedsBackfill,
};

/**
 * Tier 3 — package-internal (submodule `shared.js` only):
 *   TOLERANCE, formatEuroDe, formatEuroDeSigned.
 */

const publicSurface = {
  ...tier1BelegSnapshots,
  ...tier2BackfillSupport,
};

const API_TIERS = {
  belegSnapshots: Object.keys(tier1BelegSnapshots),
  backfillSupport: Object.keys(tier2BackfillSupport),
  packageInternal: ['TOLERANCE', 'formatEuroDe', 'formatEuroDeSigned'],
};

module.exports = { publicSurface, API_TIERS };
