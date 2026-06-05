'use strict';

const { collectLedgerUserIdCandidates } = require('../utils/canonicalUserId');

/** Types shown in Profile → Notifications → Documents (settlement + user uploads). */
const INBOX_DOCUMENT_TYPES = [
  'traderCollectionBill',
  'trade_execution_document',
  'traderCreditNote',
  'investorCollectionBill',
  'investor_collection_bill',
  'invoice',
  'monthlyAccountStatement',
  'identification',
  'address',
  'financial',
  'income',
  'tax',
  'other',
];

const EXCLUDED_TYPES = new Set(['investmentReservationEigenbeleg']);

const INVESTMENT_SCOPED_INBOX_TYPES = [
  'investorCollectionBill',
  'investor_collection_bill',
  'investmentReservationEigenbeleg',
];

/**
 * Some legacy rows store `investment.investorId` on `Document.userId` (not Parse objectId).
 * Also include bills for the session user's investments.
 * @param {string[]} userKeys
 * @returns {Promise<Parse.Query>}
 */
async function buildUserInboxDocumentQuery(userKeys) {
  const byUserId = new Parse.Query('Document');
  byUserId.containedIn('userId', userKeys);
  byUserId.containedIn('type', INBOX_DOCUMENT_TYPES);

  let investmentIds = [];
  try {
    const invQuery = new Parse.Query('Investment');
    invQuery.containedIn('investorId', userKeys);
    invQuery.limit(500);
    const investments = await invQuery.find({ useMasterKey: true });
    investmentIds = investments.map((row) => row.id).filter(Boolean);
  } catch (err) {
    console.warn('getUserDocumentInbox: Investment lookup failed:', err?.message || err);
  }

  if (investmentIds.length === 0) {
    return byUserId;
  }

  const byInvestment = new Parse.Query('Document');
  byInvestment.containedIn('investmentId', investmentIds);
  byInvestment.containedIn('type', INVESTMENT_SCOPED_INBOX_TYPES);

  return Parse.Query.or(byUserId, byInvestment);
}

/**
 * Mirrors iOS `NotificationsViewModel.isDisplayableNotificationDocument`.
 * @param {Parse.Object} doc
 */
function isDisplayableInUserInbox(doc) {
  const type = String(doc.get('type') || '');
  if (EXCLUDED_TYPES.has(type)) return false;

  const meta = doc.get('metadata') || {};
  if (meta.receiptType) return false;

  if (type === 'financial') {
    const accNo = String(doc.get('accountingDocumentNumber') || '').toUpperCase();
    if (accNo.startsWith('IAR-') || accNo.startsWith('IRR-') || accNo.startsWith('IFR-')) {
      return false;
    }
    const name = String(doc.get('name') || '').toLowerCase();
    if (name.startsWith('investorcollectionbill_')) return false;
  }
  return true;
}

/**
 * Session-only: one round-trip for Notifications → Documents inbox.
 */
async function handleGetUserDocumentInbox(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 100, skip = 0 } = request.params || {};
  const effectiveLimit = Math.min(Math.max(Number(limit) || 100, 1), 200);
  const effectiveSkip = Math.max(Number(skip) || 0, 0);

  const userKeys = collectLedgerUserIdCandidates(user);
  if (userKeys.length === 0) {
    return { documents: [], total: 0, hasMore: false };
  }

  const query = await buildUserInboxDocumentQuery(userKeys);
  query.descending('createdAt');
  query.limit(effectiveLimit);
  query.skip(effectiveSkip);

  const rows = await query.find({ useMasterKey: true });
  const displayable = rows.filter(isDisplayableInUserInbox);

  return {
    documents: displayable.map((d) => d.toJSON()),
    total: displayable.length,
    hasMore: rows.length === effectiveLimit,
  };
}

const INVESTOR_COLLECTION_BILL_TYPES = ['investor_collection_bill', 'investorCollectionBill'];

/**
 * Settlement collection bills for an investor (excludes activation/wallet receipts).
 * OR: `userId` keys + `investmentId` for the session user's investments (legacy `Document.userId`).
 * @param {string[]} userKeys
 * @returns {Promise<Parse.Query>}
 */
async function buildInvestorCollectionBillQuery(userKeys) {
  const byUserId = new Parse.Query('Document');
  byUserId.containedIn('userId', userKeys);
  byUserId.containedIn('type', INVESTOR_COLLECTION_BILL_TYPES);
  byUserId.doesNotExist('metadata.receiptType');

  let investmentIds = [];
  try {
    const invQuery = new Parse.Query('Investment');
    invQuery.containedIn('investorId', userKeys);
    invQuery.limit(500);
    const investments = await invQuery.find({ useMasterKey: true });
    investmentIds = investments.map((row) => row.id).filter(Boolean);
  } catch (err) {
    console.warn('buildInvestorCollectionBillQuery: Investment lookup failed:', err?.message || err);
  }

  if (investmentIds.length === 0) {
    return byUserId;
  }

  const byInvestment = new Parse.Query('Document');
  byInvestment.containedIn('investmentId', investmentIds);
  byInvestment.containedIn('type', INVESTOR_COLLECTION_BILL_TYPES);
  byInvestment.doesNotExist('metadata.receiptType');

  return Parse.Query.or(byUserId, byInvestment);
}

module.exports = {
  handleGetUserDocumentInbox,
  buildUserInboxDocumentQuery,
  buildInvestorCollectionBillQuery,
  isDisplayableInUserInbox,
  INBOX_DOCUMENT_TYPES,
  INVESTOR_COLLECTION_BILL_TYPES,
};
