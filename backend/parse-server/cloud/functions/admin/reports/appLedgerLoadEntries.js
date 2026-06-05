'use strict';

const { applyQuerySort } = require('../../../utils/applyQuerySort');
const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const { mapBankContraToEntry } = require('./shared');
const {
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
} = require('./appLedgerConstants');
const { mergeLegacySyntheticEntriesWhenEmpty } = require('./appLedgerLegacySynthesis');
const {
  expandLedgerAccountFilter,
  normalizeClientLiabilityAccount,
} = require('../../../utils/accountingHelper/clientLiabilityAccounts');

async function fetchRawAppLedgerRows({
  mergeBankContra,
  maxResults,
  skip,
  account,
  userId,
  /** All `_User` / ledger keys to match (from `resolveLedgerUserKeysFromParam`); overrides `userId` Parse-id heuristic. */
  resolvedUserIdKeys = null,
  transactionType,
  dateFrom,
  dateTo,
  amountMin = null,
  amountMax = null,
  requestParams,
  getMappingSnapshotForAccount,
}) {
  let entries = [];
  const queryLimit = mergeBankContra ? 2 * (maxResults + skip) : maxResults;
  const querySkip = mergeBankContra ? 0 : skip;

  try {
    const query = new Parse.Query('AppLedgerEntry');
    if (account) {
      const accountFilter = expandLedgerAccountFilter(account);
      if (accountFilter.length === 1) query.equalTo('account', accountFilter[0]);
      else query.containedIn('account', accountFilter);
    }
    if (Array.isArray(resolvedUserIdKeys) && resolvedUserIdKeys.length > 0) {
      query.containedIn('userId', resolvedUserIdKeys);
    } else if (userId && looksLikeParseObjectId(String(userId).trim())) {
      query.equalTo('userId', userId);
    }
    if (transactionType) {
      if (transactionType === TRANSACTION_TYPE_APP_SERVICE_CHARGE) {
        query.containedIn('transactionType', [
          TRANSACTION_TYPE_APP_SERVICE_CHARGE,
          LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
        ]);
      } else {
        query.equalTo('transactionType', transactionType);
      }
    }
    if (dateFrom) query.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
    if (dateTo) query.lessThanOrEqualTo('createdAt', new Date(dateTo));
    if (amountMin != null) query.greaterThanOrEqualTo('amount', amountMin);
    if (amountMax != null) query.lessThanOrEqualTo('amount', amountMax);
    applyQuerySort(query, requestParams || {}, {
      allowed: ['createdAt', 'amount'],
      defaultField: 'createdAt',
      defaultDesc: true,
    });
    query.limit(queryLimit);
    query.skip(querySkip);

    const results = await query.find({ useMasterKey: true });
    entries = results.map((e) => {
      const rowAccount = normalizeClientLiabilityAccount(e.get('account'));
      const metadata = e.get('metadata') || {};
      const mappedSnapshot = getMappingSnapshotForAccount(rowAccount) || {};
      return {
        id: e.id,
        account: rowAccount,
        side: e.get('side'),
        amount: e.get('amount'),
        userId: e.get('userId'),
        userRole: e.get('userRole'),
        transactionType: e.get('transactionType'),
        referenceId: e.get('referenceId'),
        referenceType: e.get('referenceType'),
        description: e.get('description') || '',
        createdAt: e.get('createdAt'),
        metadata,
        chartCodeSnapshot: e.get('chartCodeSnapshot') || metadata.chartCodeSnapshot || mappedSnapshot.chartCodeSnapshot || '',
        chartVersionSnapshot: e.get('chartVersionSnapshot') || metadata.chartVersionSnapshot || mappedSnapshot.chartVersionSnapshot || '',
        externalAccountNumberSnapshot:
          e.get('externalAccountNumberSnapshot') || metadata.externalAccountNumberSnapshot || mappedSnapshot.externalAccountNumberSnapshot || '',
        vatKeySnapshot: e.get('vatKeySnapshot') || metadata.vatKeySnapshot || mappedSnapshot.vatKeySnapshot || '',
        taxTreatmentSnapshot: e.get('taxTreatmentSnapshot') || metadata.taxTreatmentSnapshot || mappedSnapshot.taxTreatmentSnapshot || '',
        mappingIdSnapshot: e.get('mappingIdSnapshot') || metadata.mappingIdSnapshot || mappedSnapshot.mappingIdSnapshot || '',
      };
    });
  } catch {
    // Class may not exist yet – derive from investments
  }

  entries = await mergeLegacySyntheticEntriesWhenEmpty(entries, {
    userId,
    dateFrom,
    dateTo,
    maxResults,
    skip,
    requestParams,
    getMappingSnapshotForAccount,
  });

  if (mergeBankContra) {
    try {
      const bcQuery = new Parse.Query('BankContraPosting');
      if (userId && looksLikeParseObjectId(String(userId).trim())) bcQuery.equalTo('investorId', userId);
      if (dateFrom) bcQuery.greaterThanOrEqualTo('createdAt', new Date(dateFrom));
      if (dateTo) bcQuery.lessThanOrEqualTo('createdAt', new Date(dateTo));
      applyQuerySort(bcQuery, requestParams || {}, {
        allowed: ['createdAt', 'amount'],
        defaultField: 'createdAt',
        defaultDesc: true,
      });
      bcQuery.limit(2 * maxResults);
      const bankResults = await bcQuery.find({ useMasterKey: true });
      const bankEntries = bankResults.map(mapBankContraToEntry);
      entries = [...entries, ...bankEntries];
    } catch {
      // BankContraPosting optional
    }
  }

  return entries;
}

module.exports = {
  fetchRawAppLedgerRows,
};
