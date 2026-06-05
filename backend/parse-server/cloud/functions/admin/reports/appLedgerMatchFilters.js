'use strict';

const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const {
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
} = require('./appLedgerConstants');

function entryReferenceSearchFields(entry) {
  const metadata = entry.metadata || {};
  return [
    entry.referenceId,
    entry.referenceType,
    metadata.businessReference,
    metadata.referenceDocumentNumber,
    metadata.referenceDocumentId,
    metadata.businessCaseId,
    metadata.tradeNumber,
    metadata.investmentNumber,
  ];
}

function matchesReferenceSearch(entry, normalizedReferenceSearch) {
  if (!normalizedReferenceSearch) return true;
  return entryReferenceSearchFields(entry).some((value) =>
    String(value || '').toLowerCase().includes(normalizedReferenceSearch),
  );
}

function matchesAmountRange(entry, amountMin, amountMax) {
  const amt = Number(entry.amount) || 0;
  if (amountMin != null && amt < amountMin) return false;
  if (amountMax != null && amt > amountMax) return false;
  return true;
}

function createLedgerEntryMatchers(filters) {
  const {
    account,
    transactionType,
    dateFrom,
    dateTo,
    userId,
    amountMin = null,
    amountMax = null,
    referenceSearch = '',
  } = filters;

  const normalizedUserIdFilter = String(userId || '').trim().toLowerCase();
  const normalizedReferenceSearch = String(referenceSearch || '').trim().toLowerCase();

  function withinDateRange(createdAt) {
    const created = new Date(createdAt);
    if (dateFrom && created < new Date(dateFrom)) return false;
    if (dateTo && created > new Date(dateTo)) return false;
    return true;
  }

  function matchesFilters(entry) {
    const metadata = entry.metadata || {};
    if (account && entry.account !== account) return false;
    if (transactionType) {
      if (transactionType === TRANSACTION_TYPE_APP_SERVICE_CHARGE) {
        const isAppServiceCharge = entry.transactionType === TRANSACTION_TYPE_APP_SERVICE_CHARGE
          || entry.transactionType === LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD;
        if (!isAppServiceCharge) return false;
      } else if (entry.transactionType !== transactionType) {
        return false;
      }
    }
    if (normalizedUserIdFilter) {
      const userSearchFields = [
        String(entry.userId || '').toLowerCase(),
        String(metadata.userIdRaw || '').toLowerCase(),
        String(metadata.userCustomerNumber || '').toLowerCase(),
        String(metadata.userDisplayName || '').toLowerCase(),
        String(metadata.userUsername || '').toLowerCase(),
      ];
      const matchesUser = userSearchFields.some((value) => value.includes(normalizedUserIdFilter));
      if (!matchesUser) return false;
    }
    if (!withinDateRange(entry.createdAt)) return false;
    if (!matchesAmountRange(entry, amountMin, amountMax)) return false;
    if (!matchesReferenceSearch(entry, normalizedReferenceSearch)) return false;
    return true;
  }

  return {
    matchesFilters,
    withinDateRange,
    normalizedUserIdFilter,
    normalizedReferenceSearch,
  };
}

module.exports = {
  createLedgerEntryMatchers,
  entryReferenceSearchFields,
  matchesAmountRange,
  matchesReferenceSearch,
};
