'use strict';

const { getUserStableId, getTradeIdsForInvestorStableId } = require('../tradingIdentity');
const { buildUserInvoiceOrQueryBranches } = require('../tradingInvoiceQuery');
const { enrichServiceChargeInvoicesForDisplay } = require('./serviceChargeInvoiceEnrichment');

async function handleGetUserInvoices(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, invoiceType } = request.params || {};
  const stableId = getUserStableId(user);
  const role = String(user.get('role') || '').toLowerCase();

  let tradeIds = [];
  if (role === 'investor') {
    tradeIds = await getTradeIdsForInvestorStableId(stableId, user.id);
  }

  const branchesForFind = buildUserInvoiceOrQueryBranches({
    stableId,
    parseUserId: user.id,
    role,
    invoiceType,
    tradeIds,
  });

  const findQuery = branchesForFind.length === 1
    ? branchesForFind[0]
    : Parse.Query.or(...branchesForFind);
  findQuery.descending('invoiceDate');
  findQuery.limit(limit);
  findQuery.skip(skip);

  const invoices = await findQuery.find({ useMasterKey: true });
  const enrichedInvoices = await enrichServiceChargeInvoicesForDisplay(invoices, user);

  const branchesForCount = buildUserInvoiceOrQueryBranches({
    stableId,
    parseUserId: user.id,
    role,
    invoiceType,
    tradeIds,
  });

  const countQuery = branchesForCount.length === 1
    ? branchesForCount[0]
    : Parse.Query.or(...branchesForCount);
  countQuery.descending('invoiceDate');
  const total = await countQuery.count({ useMasterKey: true });

  return {
    invoices: enrichedInvoices.map((inv) => inv.toJSON()),
    total,
    hasMore: skip + invoices.length < total,
  };
}

module.exports = {
  handleGetUserInvoices,
};
