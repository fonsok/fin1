'use strict';

const { getUserStableId, getTradeIdsForInvestorStableId } = require('../tradingIdentity');

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

module.exports = {
  handleGetTradeInvoices,
};
