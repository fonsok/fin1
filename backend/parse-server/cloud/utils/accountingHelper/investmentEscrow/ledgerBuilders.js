'use strict';

const {
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
} = require('../accountMappingResolver');
const { TRANSACTION_TYPE, REFERENCE_TYPE } = require('./constants');

function baseFields(investorId, investmentId, leg, description, extraMeta = {}) {
  const invNum = String(extraMeta.investmentNumber || '').trim();
  const businessReference = invNum ? `Investition ${invNum}` : '';
  return {
    userId: investorId || '',
    userRole: 'investor',
    transactionType: TRANSACTION_TYPE,
    referenceId: investmentId,
    referenceType: REFERENCE_TYPE,
    description,
    metadata: Object.assign({ leg, businessReference }, extraMeta),
  };
}

function buildPairedLedgerEntries(debitAccount, creditAccount, amount, common) {
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const d = new AppLedgerEntry();
  d.set('account', debitAccount);
  const debitSnapshot = applyLedgerSnapshotToEntry(d, debitAccount);
  d.set('side', 'debit');
  d.set('amount', amount);
  d.set('userId', common.userId);
  d.set('userRole', common.userRole);
  d.set('transactionType', common.transactionType);
  d.set('referenceId', common.referenceId);
  d.set('referenceType', common.referenceType);
  d.set('description', common.description);
  d.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, { pairedAccount: creditAccount }),
    debitSnapshot,
  ));

  const c = new AppLedgerEntry();
  c.set('account', creditAccount);
  const creditSnapshot = applyLedgerSnapshotToEntry(c, creditAccount);
  c.set('side', 'credit');
  c.set('amount', amount);
  c.set('userId', common.userId);
  c.set('userRole', common.userRole);
  c.set('transactionType', common.transactionType);
  c.set('referenceId', common.referenceId);
  c.set('referenceType', common.referenceType);
  c.set('description', common.description);
  c.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, { pairedAccount: debitAccount }),
    creditSnapshot,
  ));

  return [d, c];
}

function buildSingleLedgerEntry(account, side, amount, common, extraMeta = {}) {
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const row = new AppLedgerEntry();
  row.set('account', account);
  const snapshot = applyLedgerSnapshotToEntry(row, account);
  row.set('side', side);
  row.set('amount', amount);
  row.set('userId', common.userId);
  row.set('userRole', common.userRole);
  row.set('transactionType', common.transactionType);
  row.set('referenceId', common.referenceId);
  row.set('referenceType', common.referenceType);
  row.set('description', common.description);
  row.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, extraMeta),
    snapshot,
  ));
  return row;
}

async function savePair(debitAccount, creditAccount, amount, common) {
  if (amount <= 0) return;
  const pair = buildPairedLedgerEntries(debitAccount, creditAccount, amount, common);
  await Parse.Object.saveAll(pair, { useMasterKey: true });
}

module.exports = {
  baseFields,
  buildPairedLedgerEntries,
  buildSingleLedgerEntry,
  savePair,
};
