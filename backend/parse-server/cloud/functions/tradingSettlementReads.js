'use strict';

const { getUserStableId, getTradeIdsForInvestorStableId } = require('./tradingIdentity');
const { buildUserInvoiceOrQueryBranches } = require('./tradingInvoiceQuery');

async function handleGetTradeSettlement(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params;
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId required');

  const trade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
  if (!trade) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trade not found');

  const stableId = getUserStableId(user);
  const isTradersOwnTrade = trade.get('traderId') === stableId;

  let isInvestorInTrade = false;
  if (!isTradersOwnTrade) {
    const investorInvestments = await new Parse.Query('Investment')
      .equalTo('investorId', stableId)
      .find({ useMasterKey: true });
    const investmentIds = investorInvestments.map(i => i.id);

    if (investmentIds.length > 0) {
      const participationCount = await new Parse.Query('PoolTradeParticipation')
        .equalTo('tradeId', tradeId)
        .containedIn('investmentId', investmentIds)
        .count({ useMasterKey: true });
      isInvestorInTrade = participationCount > 0;
    }
  }

  if (!isTradersOwnTrade && !isInvestorInTrade && !request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Access denied');
  }

  const accountEntries = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  const documents = await new Parse.Query('Document')
    .equalTo('tradeId', tradeId)
    .equalTo('source', 'backend')
    .find({ useMasterKey: true });

  const commissions = await new Parse.Query('Commission')
    .equalTo('tradeId', tradeId)
    .find({ useMasterKey: true });

  const userEntries = accountEntries
    .filter(e => e.get('userId') === stableId)
    .map(e => e.toJSON());

  const userDocuments = documents
    .filter(d => d.get('userId') === stableId)
    .map(d => d.toJSON());

  return {
    tradeId,
    tradeNumber: trade.get('tradeNumber'),
    grossProfit: trade.get('grossProfit') || 0,
    totalFees: trade.get('totalFees') || 0,
    netProfit: trade.get('netProfit') || 0,
    status: trade.get('status'),
    isSettledByBackend: accountEntries.length > 0,
    accountStatementEntries: userEntries,
    documents: userDocuments,
    commissions: commissions
      .filter(c => c.get('traderId') === stableId || c.get('investorId') === stableId)
      .map(c => c.toJSON()),
  };
}

async function handleGetAccountStatement(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { limit = 50, skip = 0, entryType } = request.params || {};

  const query = new Parse.Query('AccountStatement');
  query.equalTo('userId', getUserStableId(user));
  if (entryType) query.equalTo('entryType', entryType);
  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const entries = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  const investmentIds = [...new Set(
    entries
      .map((entry) => String(entry.get('investmentId') || '').trim())
      .filter((id) => /^[A-Za-z0-9]{10}$/.test(id)),
  )];
  const investmentNumberById = new Map();
  if (investmentIds.length > 0) {
    const invQuery = new Parse.Query('Investment');
    invQuery.containedIn('objectId', investmentIds);
    invQuery.limit(investmentIds.length);
    const investments = await invQuery.find({ useMasterKey: true });
    for (const investment of investments) {
      const investmentNumber = String(investment.get('investmentNumber') || '').trim();
      if (investmentNumber) investmentNumberById.set(investment.id, investmentNumber);
    }
  }

  return {
    entries: entries.map((e) => {
      const row = e.toJSON();
      const investmentId = String(e.get('investmentId') || '').trim();
      const investmentNumber = String(e.get('investmentNumber') || '').trim()
        || String(investmentNumberById.get(investmentId) || '').trim();
      if (investmentNumber) {
        row.investmentNumber = investmentNumber;
        row.businessReference = investmentNumber;
      }
      return row;
    }),
    total,
    hasMore: skip + entries.length < total,
  };
}

async function handleGetTradeInvoices(request) {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { tradeId } = request.params || {};
  if (!tradeId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'tradeId is required');

  const stableId = getUserStableId(user);
  const role = String(user.get('role') || '').toLowerCase();

  const query = new Parse.Query('Invoice');
  query.equalTo('tradeId', tradeId);
  if (role === 'investor') {
    const allowedTradeIds = await getTradeIdsForInvestorStableId(stableId, user.id);
    if (!allowedTradeIds.includes(String(tradeId))) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Kein Zugriff auf diesen Trade.');
    }
    query.containedIn('invoiceType', ['buy_invoice', 'sell_invoice', 'buy', 'sell']);
  } else {
    const ownerKeys = [stableId, user.id].filter((v) => typeof v === 'string' && v.trim().length > 0);
    query.containedIn('userId', [...new Set(ownerKeys)]);
  }
  query.descending('invoiceDate');

  const invoices = await query.find({ useMasterKey: true });

  return {
    invoices: invoices.map(inv => inv.toJSON()),
    count: invoices.length,
  };
}

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
    invoices: invoices.map(inv => inv.toJSON()),
    total,
    hasMore: skip + invoices.length < total,
  };
}

module.exports = {
  handleGetTradeSettlement,
  handleGetAccountStatement,
  handleGetTradeInvoices,
  handleGetUserInvoices,
};
