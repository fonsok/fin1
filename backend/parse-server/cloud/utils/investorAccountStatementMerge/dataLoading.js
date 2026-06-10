'use strict';

const { collectLedgerUserIdCandidates } = require('../canonicalUserId');
const {
  CLT_LIAB_AVA,
  normalizeClientLiabilityAccount,
} = require('../accountingHelper/clientLiabilityAccounts');
const {
  INVESTMENT_REF_TYPES,
  ESCROW_TX_TYPES,
  INVESTOR_STMT_SOURCE_LIMIT,
  INVESTOR_ESCROW_SOURCE_LIMIT,
  dedupeParseObjectsById,
} = require('./shared');

async function listInvestorInvestmentIds(user) {
  if (!user?.id || user.get('role') !== 'investor') return [];
  const keys = new Set([user.id]);
  const email = String(user.get('email') || '').toLowerCase().trim();
  if (email) keys.add(`user:${email}`);
  const queries = [...keys].map((investorId) => {
    const q = new Parse.Query('Investment');
    q.equalTo('investorId', investorId);
    return q;
  });
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.select('objectId');
  combined.limit(500);
  const rows = await combined.find({ useMasterKey: true });
  return rows.map((r) => r.id);
}

async function fetchAccountStatementRowsForInvestor({ userKeys, investmentIds }) {
  const queries = [];
  if (userKeys?.length) {
    const q = new Parse.Query('AccountStatement');
    q.containedIn('userId', userKeys);
    queries.push(q);
  }
  if (investmentIds?.length) {
    const q = new Parse.Query('AccountStatement');
    q.containedIn('investmentId', investmentIds);
    queries.push(q);
  }
  if (queries.length === 0) return { rows: [], truncated: false };
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.ascending('createdAt');
  combined.limit(INVESTOR_STMT_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await combined.find({ useMasterKey: true }));
  const truncated = fetched.length > INVESTOR_STMT_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, INVESTOR_STMT_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

async function fetchInvestorEscrowLedgerRows(userKeys, investmentIds) {
  const queries = [];
  if (userKeys?.length) {
    const q = new Parse.Query('AppLedgerEntry');
    q.containedIn('userId', userKeys);
    q.containedIn('transactionType', ESCROW_TX_TYPES);
    queries.push(q);
  }
  if (investmentIds?.length) {
    const q = new Parse.Query('AppLedgerEntry');
    q.containedIn('referenceId', investmentIds);
    q.containedIn('referenceType', INVESTMENT_REF_TYPES);
    q.equalTo('transactionType', 'investmentEscrow');
    queries.push(q);
  }
  if (queries.length === 0) return { rows: [], truncated: false };
  const combined = queries.length === 1 ? queries[0] : Parse.Query.or(...queries);
  combined.ascending('createdAt');
  combined.limit(INVESTOR_ESCROW_SOURCE_LIMIT + 1);
  const fetched = dedupeParseObjectsById(await combined.find({ useMasterKey: true }));
  const truncated = fetched.length > INVESTOR_ESCROW_SOURCE_LIMIT;
  return {
    rows: truncated ? fetched.slice(0, INVESTOR_ESCROW_SOURCE_LIMIT) : fetched,
    truncated,
  };
}

async function fetchInvestorAvaCashLedgerRows(userKeys, investmentIds = []) {
  const { rows: allEscrow } = await fetchInvestorEscrowLedgerRows(userKeys, investmentIds);
  return allEscrow.filter((row) => normalizeClientLiabilityAccount(row.get('account')) === CLT_LIAB_AVA);
}

/**
 * SSOT: AccountStatement + AVA-Escrow-Zeilen für Investor (Admin getUserDetails + App getAccountStatement).
 */
async function loadInvestorAccountStatementSourceData(user) {
  const userKeys = collectLedgerUserIdCandidates(user);
  const investmentIds = await listInvestorInvestmentIds(user);
  const stmtResult = await fetchAccountStatementRowsForInvestor({ userKeys, investmentIds });
  let avaRows = [];
  let escrowTruncated = false;
  if (userKeys.length > 0 || investmentIds.length > 0) {
    const escrowResult = await fetchInvestorEscrowLedgerRows(userKeys, investmentIds);
    escrowTruncated = escrowResult.truncated;
    avaRows = escrowResult.rows.filter(
      (row) => normalizeClientLiabilityAccount(row.get('account')) === CLT_LIAB_AVA,
    );
  }
  return {
    userKeys,
    investmentIds,
    stmtEntries: stmtResult.rows,
    avaRows,
    sourceTruncated: stmtResult.truncated || escrowTruncated,
  };
}

module.exports = {
  listInvestorInvestmentIds,
  fetchAccountStatementRowsForInvestor,
  fetchInvestorEscrowLedgerRows,
  fetchInvestorAvaCashLedgerRows,
  loadInvestorAccountStatementSourceData,
};
