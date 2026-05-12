'use strict';

const INVESTOR_TRADE_INVOICE_TYPES = ['buy_invoice', 'sell_invoice', 'buy', 'sell'];

/**
 * @param {{ stableId: string, parseUserId?: string, role: string, invoiceType?: string, tradeIds: string[] }} p
 *
 * `Invoice.userId` historically may carry either the stable id (`user:email`) or the
 * Parse `_User.objectId`. Match both. See triggers/order#createOrderInvoice.
 */
function buildUserInvoiceOrQueryBranches(p) {
  const branches = [];
  const { stableId, parseUserId, role, invoiceType, tradeIds } = p;

  const ownerKeys = [...new Set(
    [stableId, parseUserId]
      .filter((v) => typeof v === 'string' && v.trim().length > 0)
      .map((v) => v.trim()),
  )];

  const qOwn = new Parse.Query('Invoice');
  if (ownerKeys.length === 1) {
    qOwn.equalTo('userId', ownerKeys[0]);
  } else {
    qOwn.containedIn('userId', ownerKeys);
  }
  if (invoiceType) qOwn.equalTo('invoiceType', invoiceType);
  branches.push(qOwn);

  const typeStr = invoiceType ? String(invoiceType) : '';
  const investorWantsOnlyNonTradeType = typeStr && !INVESTOR_TRADE_INVOICE_TYPES.includes(typeStr);

  if (
    String(role).toLowerCase() === 'investor' &&
    !investorWantsOnlyNonTradeType &&
    tradeIds.length > 0
  ) {
    const qTrade = new Parse.Query('Invoice');
    qTrade.containedIn('tradeId', tradeIds);
    qTrade.containedIn('invoiceType', INVESTOR_TRADE_INVOICE_TYPES);
    if (typeStr && INVESTOR_TRADE_INVOICE_TYPES.includes(typeStr)) {
      qTrade.equalTo('invoiceType', typeStr);
    }
    branches.push(qTrade);
  }

  return branches;
}

module.exports = {
  buildUserInvoiceOrQueryBranches,
};
