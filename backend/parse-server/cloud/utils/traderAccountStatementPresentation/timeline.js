'use strict';

const { round2 } = require('../accountingHelper/shared');
const {
  CUSTOMER_PASSTHROUGH_ENTRY_TYPES,
  customerDisplayEntryRank,
} = require('./shared');
const {
  buildNetTradeDisplayEvents,
  isTraderCustomerVisibleTrade,
} = require('./netTradeDisplay');
const { buildDisplayEventFromStatementEntry } = require('./passthrough');
const {
  loadTradeInstrumentContext,
  collectTradeIdsFromSources,
} = require('./dataLoading');
const { enrichTimelineWithTradeInstruments } = require('./instruments');

/**
 * Chronologische Timeline (älteste zuerst) inkl. laufendem Saldo.
 */
function buildTraderCustomerTimeline({
  stmtEntries,
  invoices,
  initialBalance,
  instrumentContext = {},
}) {
  const { tradeById = new Map(), buyOrderByTradeId = new Map() } = instrumentContext;
  const tradeEvents = buildNetTradeDisplayEvents(stmtEntries, invoices, instrumentContext);
  const latestTradeAt = new Map();

  for (const event of tradeEvents) {
    const atMs = event.at instanceof Date ? event.at.getTime() : 0;
    if (event.tradeId) {
      const key = `id:${event.tradeId}`;
      const prev = latestTradeAt.get(key) || 0;
      if (atMs >= prev) latestTradeAt.set(key, atMs);
    }
    if (event.tradeNumber != null && event.tradeNumber !== '') {
      const key = `num:${event.tradeNumber}`;
      const prev = latestTradeAt.get(key) || 0;
      if (atMs >= prev) latestTradeAt.set(key, atMs);
    }
  }

  const passthrough = stmtEntries
    .filter((entry) => CUSTOMER_PASSTHROUGH_ENTRY_TYPES.has(String(entry.get('entryType') || '')))
    .filter((entry) => isTraderCustomerVisibleTrade(
      entry.get('tradeId'),
      tradeById,
      buyOrderByTradeId,
    ))
    .map(buildDisplayEventFromStatementEntry);

  for (const event of passthrough) {
    if (event.entryType !== 'commission_credit') continue;
    const tradeLatest = (event.tradeId && latestTradeAt.get(`id:${event.tradeId}`))
      || (event.tradeNumber != null && latestTradeAt.get(`num:${event.tradeNumber}`))
      || 0;
    if (tradeLatest) {
      event.at = new Date(tradeLatest + 1);
    }
  }

  const combined = [...tradeEvents, ...passthrough].sort((a, b) => {
    const ta = a.at instanceof Date ? a.at.getTime() : 0;
    const tb = b.at instanceof Date ? b.at.getTime() : 0;
    if (ta !== tb) return ta - tb;
    const rankDiff = customerDisplayEntryRank(a.entryType) - customerDisplayEntryRank(b.entryType);
    if (rankDiff !== 0) return rankDiff;
    return String(a.objectId).localeCompare(String(b.objectId));
  });

  let running = round2(initialBalance);
  return combined.map((event) => {
    const balanceBefore = running;
    running = round2(running + event.amount);
    return {
      ...event,
      balanceBefore,
      balanceAfter: running,
    };
  });
}

/**
 * Builds customer timeline with optional Trade/Order instrument enrichment.
 */
async function buildTraderCustomerTimelineForUser({ stmtEntries, invoices, initialBalance }) {
  const tradeIds = collectTradeIdsFromSources(stmtEntries, invoices, []);
  const instrumentContext = await loadTradeInstrumentContext(tradeIds);
  let timeline = buildTraderCustomerTimeline({
    stmtEntries,
    invoices,
    initialBalance,
    instrumentContext,
  });
  timeline = enrichTimelineWithTradeInstruments(timeline, instrumentContext);
  return timeline;
}

module.exports = {
  buildTraderCustomerTimeline,
  buildTraderCustomerTimelineForUser,
};
