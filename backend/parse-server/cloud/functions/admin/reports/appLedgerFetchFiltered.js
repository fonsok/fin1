'use strict';

const { resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const { sortPlainLedgerEntries } = require('./appLedgerCoreHelpers');
const { fetchRawAppLedgerRows } = require('./appLedgerLoadEntries');
const { enrichLedgerRowsForReporting } = require('./appLedgerNormalizePipeline');
const { APP_LEDGER_MEMORY_FILTER_SCAN_LIMIT } = require('./appLedgerListFilters');

function parseUserIdForDbQuery(userId) {
  const trimmed = String(userId || '').trim();
  if (!trimmed) return null;
  if (looksLikeParseObjectId(trimmed)) return trimmed;
  return null;
}

async function fetchFilteredAppLedgerEntries({
  filters,
  matchesFilters,
  useMemoryFilterPath,
  requestParams,
  getMappingSnapshotForAccount,
}) {
  const sortOrder = resolveListSortOrder(requestParams || {});
  const dbUserId = parseUserIdForDbQuery(filters.userId);

  const fetchParams = {
    mergeBankContra: false,
    account: filters.account,
    userId: dbUserId,
    transactionType: filters.transactionType,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
    amountMin: filters.amountMin,
    amountMax: filters.amountMax,
    requestParams,
    getMappingSnapshotForAccount,
  };

  if (useMemoryFilterPath) {
    const rows = await fetchRawAppLedgerRows({
      ...fetchParams,
      maxResults: APP_LEDGER_MEMORY_FILTER_SCAN_LIMIT,
      skip: 0,
    });
    const enriched = await enrichLedgerRowsForReporting(rows);
    const filtered = enriched.filter(matchesFilters);
    sortPlainLedgerEntries(filtered, filters.sortBy, sortOrder);
    return {
      filtered,
      paginated: filtered.slice(filters.skip, filters.skip + filters.limit),
      totalCount: filtered.length,
      filterScanTruncated: rows.length >= APP_LEDGER_MEMORY_FILTER_SCAN_LIMIT,
    };
  }

  const rows = await fetchRawAppLedgerRows({
    ...fetchParams,
    maxResults: filters.limit,
    skip: filters.skip,
  });
  const enriched = await enrichLedgerRowsForReporting(rows);
  const filtered = enriched.filter(matchesFilters);
  sortPlainLedgerEntries(filtered, filters.sortBy, sortOrder);

  return {
    filtered,
    paginated: filtered,
    totalCount: null,
    filterScanTruncated: false,
  };
}

module.exports = {
  fetchFilteredAppLedgerEntries,
  parseUserIdForDbQuery,
};
