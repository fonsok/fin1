'use strict';

const { resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { getMappedAccounts, getMappingSnapshotForAccount } = require('./shared');
const { sortPlainLedgerEntries } = require('./appLedgerCoreHelpers');
const { createLedgerEntryMatchers } = require('./appLedgerMatchFilters');
const { fetchAppLedgerViaBankContraPosting } = require('./appLedgerBankPath');
const { fetchRawAppLedgerRows } = require('./appLedgerLoadEntries');
const { enrichLedgerRowsForReporting } = require('./appLedgerNormalizePipeline');
const { buildAppLedgerTotalsAndCounts } = require('./appLedgerResponseMetrics');
const { isStrictMappingEnabled } = require('../../../utils/accountingHelper/accountMappingResolver');

async function handleGetAppLedger(request) {
  const {
    account,
    userId,
    transactionType,
    dateFrom,
    dateTo,
    limit: maxResults = 500,
    skip = 0,
    sortBy,
  } = request.params || {};

  const isBankContraAccount = account === 'BANK-PS-NET' || account === 'BANK-PS-VAT';

  const { matchesFilters, normalizedUserIdFilter } = createLedgerEntryMatchers({
    account,
    transactionType,
    dateFrom,
    dateTo,
    userId,
  });

  if (isBankContraAccount) {
    return fetchAppLedgerViaBankContraPosting({
      request,
      account,
      maxResults,
      skip,
      sortBy,
      userId,
      dateFrom,
      dateTo,
      matchesFilters,
    });
  }

  const mergeBankContra = false;
  const entries = await fetchRawAppLedgerRows({
    mergeBankContra,
    maxResults,
    skip,
    account,
    userId,
    transactionType,
    dateFrom,
    dateTo,
    requestParams: request.params || {},
    getMappingSnapshotForAccount,
  });

  const withUserDisplayEntries = await enrichLedgerRowsForReporting(entries);
  const filtered = withUserDisplayEntries.filter(matchesFilters);
  sortPlainLedgerEntries(filtered, sortBy, resolveListSortOrder(request.params || {}));
  const paginated = filtered.slice(skip, skip + maxResults);

  const {
    totals,
    totalRevenue,
    totalRefunds,
    vatSummary,
    effectiveTotalCount,
  } = await buildAppLedgerTotalsAndCounts({
    filtered,
    account,
    userId,
    transactionType,
    dateFrom,
    dateTo,
    normalizedUserIdFilter,
  });

  return {
    entries: paginated,
    totals,
    totalRevenue: Math.round(totalRevenue * 100) / 100,
    totalRefunds: Math.round(totalRefunds * 100) / 100,
    vatSummary,
    totalCount: effectiveTotalCount,
    accounts: getMappedAccounts(),
    strictMappingEnabled: isStrictMappingEnabled(),
  };
}

module.exports = {
  handleGetAppLedger,
};
