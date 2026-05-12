'use strict';

const { applyQuerySort } = require('../../../utils/applyQuerySort');
const { looksLikeParseObjectId } = require('./appLedgerParseIds');
const { mapBankContraToEntry } = require('./shared');
const {
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
} = require('./appLedgerConstants');
const { mergeLegacySyntheticEntriesWhenEmpty } = require('./appLedgerLegacySynthesis');

async function fetchRawAppLedgerRows({
  mergeBankContra,
  maxResults,
  skip,
  account,
  userId,
  transactionType,
  dateFrom,
  dateTo,
  requestParams,
  getMappingSnapshotForAccount,
}) {
  let entries = [];
  const queryLimit = mergeBankContra ? 2 * (maxResults + skip) : maxResults + skip;
  const querySkip = 0;

  try {
    const query = new Parse.Query('AppLedgerEntry');
    if (account) query.equalTo('account', account);
    if (userId && looksLikeParseObjectId(String(userId).trim())) query.equalTo('userId', userId);
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
    applyQuerySort(query, requestParams || {}, {
      allowed: ['createdAt', 'amount'],
      defaultField: 'createdAt',
      defaultDesc: true,
    });
    query.limit(queryLimit);
    query.skip(querySkip);

    const results = await query.find({ useMasterKey: true });
    entries = results.map((e) => {
      const rowAccount = e.get('account');
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
