'use strict';

const { deriveSoldQuantity } = require('../../triggers/tradeSellQuantityHelpers');
const { buildExcludePoolMirrorLegParseQuery } = require('../../functions/admin/reports/summaryReportTradeListVisibility');
const { resolveMaxOpenDepotPositions } = require('./resolveMaxOpenDepotPositions');

const QTY_EPS = 1e-6;

function buyQuantityFromTrade(trade) {
  const buyOrder = trade.get ? (trade.get('buyOrder') || {}) : (trade.buyOrder || {});
  return Number(
    (trade.get ? trade.get('quantity') : trade.quantity)
    || buyOrder.quantity
    || 0,
  );
}

function soldQuantityFromTrade(trade) {
  const explicit = Number(trade.get ? trade.get('soldQuantity') : trade.soldQuantity);
  if (Number.isFinite(explicit) && explicit >= 0) {
    const fromOrders = deriveSoldQuantity(trade);
    return Math.max(explicit, fromOrders);
  }
  return deriveSoldQuantity(trade);
}

function tradeHasOpenDepotPosition(trade) {
  const buyQty = buyQuantityFromTrade(trade);
  if (!(buyQty > QTY_EPS)) {
    return false;
  }
  const soldQty = soldQuantityFromTrade(trade);
  return soldQty < buyQty - QTY_EPS;
}

/**
 * Counts trader-visible open depot positions (TRADER leg, remaining quantity > 0).
 * @param {string} traderId
 * @returns {Promise<number>}
 */
async function countOpenTraderDepotPositions(traderId) {
  if (!traderId) {
    return 0;
  }

  const baseQuery = new Parse.Query('Trade');
  baseQuery.equalTo('traderId', traderId);
  baseQuery.containedIn('status', ['pending', 'active', 'partial']);

  const visibilityQuery = buildExcludePoolMirrorLegParseQuery();
  const query = Parse.Query.and(baseQuery, visibilityQuery);
  const trades = await query.find({ useMasterKey: true });

  return trades.filter(tradeHasOpenDepotPosition).length;
}

/**
 * Blocks a new paired buy when the trader already holds the maximum open depot positions.
 * @param {string} traderId
 * @param {{ limitOverride?: number }} [options]
 */
async function assertTraderCanOpenNewDepotPosition(traderId, options = {}) {
  const resolved = Number.isFinite(options.limitOverride)
    ? { limit: Math.floor(options.limitOverride), source: 'override' }
    : await resolveMaxOpenDepotPositions({ traderId });

  const openCount = await countOpenTraderDepotPositions(traderId);
  if (openCount >= resolved.limit) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Maximal ${resolved.limit} offene Depot-Position${resolved.limit === 1 ? '' : 'en'} erlaubt `
      + `(aktuell ${openCount}). Bitte schließen Sie eine Position, bevor Sie eine neue eröffnen.`,
    );
  }
}

module.exports = {
  countOpenTraderDepotPositions,
  assertTraderCanOpenNewDepotPosition,
  tradeHasOpenDepotPosition,
};
