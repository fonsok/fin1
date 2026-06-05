'use strict';

const { looksLikeParseObjectId } = require('./appLedgerParseIds');

/** Max rows loaded from DB when post-fetch filters (Beleg-Text, fuzzy User) are active. */
const APP_LEDGER_MEMORY_FILTER_SCAN_LIMIT = 5000;

const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 500;

function parseOptionalAmount(raw) {
  if (raw === undefined || raw === null || raw === '') return null;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0) return null;
  return Math.round(n * 100) / 100;
}

function parseAppLedgerListFilters(params = {}) {
  const amountMin = parseOptionalAmount(params.amountMin);
  let amountMax = parseOptionalAmount(params.amountMax);
  if (amountMin != null && amountMax != null && amountMax < amountMin) {
    amountMax = amountMin;
  }

  const limitRaw = Number(params.limit);
  const limit = Number.isFinite(limitRaw)
    ? Math.min(Math.max(Math.floor(limitRaw), 1), MAX_LIMIT)
    : DEFAULT_LIMIT;
  const skipRaw = Number(params.skip);
  const skip = Number.isFinite(skipRaw) ? Math.max(Math.floor(skipRaw), 0) : 0;

  return {
    account: String(params.account || '').trim() || null,
    userId: String(params.userId || '').trim() || null,
    transactionType: String(params.transactionType || '').trim() || null,
    dateFrom: params.dateFrom || null,
    dateTo: params.dateTo || null,
    amountMin,
    amountMax,
    referenceSearch: String(params.referenceSearch || params.belegSearch || '').trim(),
    limit,
    skip,
    sortBy: params.sortBy,
    sortOrder: params.sortOrder,
  };
}

function requiresMemoryFilter(filters) {
  if (filters.referenceSearch) return true;
  const uid = String(filters.userId || '').trim();
  return Boolean(uid && !looksLikeParseObjectId(uid));
}

module.exports = {
  APP_LEDGER_MEMORY_FILTER_SCAN_LIMIT,
  parseAppLedgerListFilters,
  parseOptionalAmount,
  requiresMemoryFilter,
};
