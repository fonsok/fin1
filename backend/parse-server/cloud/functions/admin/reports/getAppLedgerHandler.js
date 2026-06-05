'use strict';

const { resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { getMappedAccounts, getMappingSnapshotForAccount } = require('./shared');
const { createLedgerEntryMatchers } = require('./appLedgerMatchFilters');
const { fetchAppLedgerViaBankContraPosting } = require('./appLedgerBankPath');
const { buildAppLedgerTotalsAndCounts } = require('./appLedgerResponseMetrics');
const { isStrictMappingEnabled } = require('../../../utils/accountingHelper/accountMappingResolver');
const { parseAppLedgerListFilters, requiresMemoryFilter } = require('./appLedgerListFilters');
const { fetchFilteredAppLedgerEntries } = require('./appLedgerFetchFiltered');

async function handleGetAppLedger(request) {
  const filters = parseAppLedgerListFilters(request.params || {});
  const useMemoryFilterPath = requiresMemoryFilter(filters);

  const { matchesFilters, normalizedUserIdFilter } = createLedgerEntryMatchers(filters);

  const isBankContraAccount = filters.account === 'BANK-PS-NET' || filters.account === 'BANK-PS-VAT';
  if (isBankContraAccount) {
    return fetchAppLedgerViaBankContraPosting({
      request,
      account: filters.account,
      maxResults: filters.limit,
      skip: filters.skip,
      sortBy: filters.sortBy,
      userId: filters.userId,
      dateFrom: filters.dateFrom,
      dateTo: filters.dateTo,
      amountMin: filters.amountMin,
      amountMax: filters.amountMax,
      matchesFilters,
    });
  }

  const {
    filtered,
    paginated,
    totalCount: memoryTotalCount,
    filterScanTruncated,
  } = await fetchFilteredAppLedgerEntries({
    filters,
    matchesFilters,
    useMemoryFilterPath,
    requestParams: request.params || {},
    getMappingSnapshotForAccount,
  });

  const {
    totals,
    totalRevenue,
    totalRefunds,
    vatSummary,
    effectiveTotalCount,
  } = await buildAppLedgerTotalsAndCounts({
    filtered,
    account: filters.account,
    userId: filters.userId,
    transactionType: filters.transactionType,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
    amountMin: filters.amountMin,
    amountMax: filters.amountMax,
    normalizedUserIdFilter,
    useMemoryFilterPath,
    memoryTotalCount,
  });

  return {
    entries: paginated,
    totals,
    totalRevenue: Math.round(totalRevenue * 100) / 100,
    totalRefunds: Math.round(totalRefunds * 100) / 100,
    vatSummary,
    totalCount: effectiveTotalCount,
    filterScanTruncated: useMemoryFilterPath ? filterScanTruncated : false,
    accounts: getMappedAccounts(),
    strictMappingEnabled: isStrictMappingEnabled(),
  };
}

module.exports = {
  handleGetAppLedger,
};
