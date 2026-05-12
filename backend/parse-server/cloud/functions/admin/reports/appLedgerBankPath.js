'use strict';

const { applyQuerySort, resolveListSortOrder } = require('../../../utils/applyQuerySort');
const { mapBankContraToEntry, getMappedAccounts } = require('./shared');
const { sortPlainLedgerEntries } = require('./appLedgerCoreHelpers');
const { totalsByAccountFromEntries } = require('./appLedgerTotalsMath');
const { looksLikeParseObjectId } = require('./appLedgerParseIds');

async function fetchAppLedgerViaBankContraPosting({
  request,
  account,
  maxResults,
  skip,
  sortBy,
  userId,
  dateFrom,
  dateTo,
  matchesFilters,
}) {
  let bankEntries = [];
  try {
    const bcQuery = new Parse.Query('BankContraPosting');
    bcQuery.equalTo('account', account);
    if (userId && looksLikeParseObjectId(String(userId).trim())) bcQuery.equalTo('investorId', userId);
    if (dateFrom) bcQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
    if (dateTo) bcQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
    applyQuerySort(bcQuery, request.params || {}, {
      allowed: ['createdAt', 'amount'],
      defaultField: 'createdAt',
      defaultDesc: true,
    });
    bcQuery.limit(maxResults + skip);
    const results = await bcQuery.find({ useMasterKey: true });
    bankEntries = results.map(mapBankContraToEntry);
  } catch {
    // BankContraPosting class may not exist
  }

  const filteredBankEntries = bankEntries.filter(matchesFilters);
  const sortOrder = resolveListSortOrder(request.params || {});
  sortPlainLedgerEntries(filteredBankEntries, sortBy, sortOrder);
  const paginatedBankEntries = filteredBankEntries.slice(skip, skip + maxResults);

  const totals = totalsByAccountFromEntries(filteredBankEntries);
  const totalRevenue = 0;
  const totalRefunds = 0;
  const vatSummary = {
    outputVATCollected: 0,
    outputVATRemitted: 0,
    inputVATClaimed: 0,
    outstandingVATLiability: 0,
  };

  return {
    entries: paginatedBankEntries,
    totals,
    totalRevenue,
    totalRefunds,
    vatSummary,
    totalCount: filteredBankEntries.length,
    accounts: getMappedAccounts(),
  };
}

module.exports = {
  fetchAppLedgerViaBankContraPosting,
};
