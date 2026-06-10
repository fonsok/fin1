'use strict';

const TRADE_CASH_ENTRY_TYPES = new Set(['trade_buy', 'trade_sell']);
const CUSTOMER_PASSTHROUGH_ENTRY_TYPES = new Set([
  'commission_credit',
  'deposit',
  'withdrawal',
]);

const CUSTOMER_DISPLAY_ENTRY_RANK = Object.freeze({
  deposit: 5,
  withdrawal: 5,
  trade_buy: 10,
  trade_sell: 30,
  trading_fees: 40,
  commission_credit: 70,
});

function customerDisplayEntryRank(entryType) {
  return CUSTOMER_DISPLAY_ENTRY_RANK[String(entryType || '')] ?? 50;
}

const SETTLEMENT_INVOICE_TYPES = new Set([
  'buy',
  'sell',
  'buy_invoice',
  'sell_invoice',
]);

/** Max source rows loaded per AccountStatement / Invoice query (timeline may be shorter after merge). */
const TIMELINE_SOURCE_LIMIT = 500;

function dedupeParseObjectsById(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    if (!row?.id || seen.has(row.id)) return false;
    seen.add(row.id);
    return true;
  });
}

function iso(d) {
  if (!d || !(d instanceof Date)) return new Date(0).toISOString();
  return d.toISOString();
}

module.exports = {
  TRADE_CASH_ENTRY_TYPES,
  CUSTOMER_PASSTHROUGH_ENTRY_TYPES,
  CUSTOMER_DISPLAY_ENTRY_RANK,
  customerDisplayEntryRank,
  SETTLEMENT_INVOICE_TYPES,
  TIMELINE_SOURCE_LIMIT,
  dedupeParseObjectsById,
  iso,
};
