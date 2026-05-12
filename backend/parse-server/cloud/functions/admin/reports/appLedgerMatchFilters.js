'use strict';

const {
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
} = require('./appLedgerConstants');

function createLedgerEntryMatchers({
  account,
  transactionType,
  dateFrom,
  dateTo,
  userId,
}) {
  const normalizedUserIdFilter = String(userId || '').trim().toLowerCase();

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
    return true;
  }

  return { matchesFilters, withinDateRange, normalizedUserIdFilter };
}

module.exports = {
  createLedgerEntryMatchers,
};
