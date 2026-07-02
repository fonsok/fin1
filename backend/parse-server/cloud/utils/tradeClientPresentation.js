'use strict';

const { resolveTradeRealizedGrossProfit } = require('../triggers/tradeRealizedGrossProfit');
const {
  resolveTradeNumberYear,
  resolveTradeNumberPresentation,
} = require('./tradeNumberAllocation');

/**
 * Normalizes Parse Trade rows for iOS `ParseTrade` / `ParseOrderBuy` decoding.
 * Server-created trades (order afterSave) use minimal embedded buyOrder snapshots.
 */

function isoOrNow(value) {
  if (value == null) return new Date().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'object' && value.iso) return String(value.iso);
  if (typeof value === 'string' && value.trim()) return value.trim();
  return new Date().toISOString();
}

function normalizeBuyOrderSnapshot(buyOrder, trade) {
  const snap = buyOrder && typeof buyOrder === 'object' ? { ...buyOrder } : {};
  const traderId = String(snap.traderId || trade.get('traderId') || '').trim();
  const symbol = String(snap.symbol || trade.get('symbol') || snap.wkn || trade.get('wkn') || '').trim();
  const description = String(
    snap.description
    || trade.get('description')
    || trade.get('securityName')
    || symbol,
  ).trim();
  const qty = Number(
    snap.quantity
    ?? snap.executedQuantity
    ?? trade.get('quantity')
    ?? 0,
  );
  const price = Number(snap.price ?? trade.get('buyPrice') ?? 0);
  const totalAmount = Number(
    snap.totalAmount
    ?? trade.get('buyAmount')
    ?? (qty > 0 && price > 0 ? qty * price : 0),
  );
  const orderId = String(snap.id || snap.objectId || trade.get('buyOrderId') || '').trim();
  const now = isoOrNow(trade.get('createdAt') || trade.createdAt);

  return {
    ...snap,
    id: orderId || snap.id || snap.objectId || `trade-buy-${trade.id}`,
    objectId: snap.objectId || orderId || snap.id,
    traderId,
    symbol,
    description: description || symbol || '—',
    quantity: qty,
    price,
    totalAmount: totalAmount > 0 ? totalAmount : 0,
    status: String(snap.status || 'executed'),
    createdAt: isoOrNow(snap.createdAt || now),
    updatedAt: isoOrNow(snap.updatedAt || snap.createdAt || now),
    executedAt: snap.executedAt != null ? isoOrNow(snap.executedAt) : now,
    confirmedAt: snap.confirmedAt != null ? isoOrNow(snap.confirmedAt) : null,
    wkn: snap.wkn || trade.get('wkn') || symbol || null,
    isMirrorPoolOrder: snap.isMirrorPoolOrder === true,
    legType: snap.legType || null,
  };
}

function normalizeTradeForClient(trade) {
  const json = typeof trade.toJSON === 'function' ? trade.toJSON() : { ...trade };
  const get = typeof trade.get === 'function' ? (k) => trade.get(k) : () => undefined;
  const description = String(
    json.description
    || get('description')
    || json.securityName
    || get('securityName')
    || json.symbol
    || get('symbol')
    || '',
  ).trim();

  const createdAt = isoOrNow(json.createdAt);
  const updatedAt = isoOrNow(json.updatedAt || json.createdAt);

  const normalized = {
    ...json,
    objectId: json.objectId || trade.id,
    description: description || json.symbol || '—',
    createdAt,
    updatedAt,
    completedAt: json.completedAt != null ? isoOrNow(json.completedAt) : json.completedAt,
    tradeNumber: json.tradeNumber != null ? json.tradeNumber : trade.get('tradeNumber'),
    tradeNumberYear: json.tradeNumberYear != null ? json.tradeNumberYear : trade.get('tradeNumberYear'),
    traderId: String(json.traderId || trade.get('traderId') || ''),
    symbol: String(json.symbol || trade.get('symbol') || ''),
    status: String(json.status || trade.get('status') || 'active'),
  };

  const presentation = resolveTradeNumberPresentation(trade);
  if (presentation.formattedTradeNumber) {
    normalized.formattedTradeNumber = presentation.formattedTradeNumber;
  }

  if (json.buyOrder || trade.get('buyOrder')) {
    normalized.buyOrder = normalizeBuyOrderSnapshot(json.buyOrder || trade.get('buyOrder'), trade);
  }

  const legType = String(
    json.buyLegType
    || get('buyLegType')
    || normalized.buyOrder?.legType
    || '',
  ).trim();
  if (legType) {
    normalized.buyLegType = legType;
  }

  const pairExecutionId = String(
    json.pairExecutionId
    || get('pairExecutionId')
    || '',
  ).trim();
  if (pairExecutionId) {
    normalized.pairExecutionId = pairExecutionId;
  }

  const realized = resolveTradeRealizedGrossProfit(trade);
  if (realized !== null && Number.isFinite(realized)) {
    normalized.calculatedProfit = realized;
    normalized.grossProfit = realized;
    const buyAmt = Number(
      normalized.buyAmount
      || normalized.buyOrder?.totalAmount
      || 0,
    );
    if (buyAmt > 0) {
      normalized.profitPercentage = (realized / buyAmt) * 100;
    }
  }

  return normalized;
}

/**
 * Fills leg metadata on Trade rows from linked Order (legacy trades lack embed flags).
 * @param {Parse.Object[]} trades
 * @returns {Promise<Parse.Object[]>}
 */
async function enrichTradesWithOrderLegs(trades) {
  if (!Array.isArray(trades) || trades.length === 0) return trades;

  const orderIds = trades.map((trade) => {
    const snap = trade.get('buyOrder');
    return String(trade.get('buyOrderId') || snap?.objectId || snap?.id || '').trim();
  }).filter(Boolean);

  if (orderIds.length === 0) return trades;

  const orders = await new Parse.Query('Order')
    .containedIn('objectId', [...new Set(orderIds)])
    .limit(Math.min(orderIds.length, 1000))
    .find({ useMasterKey: true });

  const orderById = new Map(orders.map((o) => [o.id, o]));

  for (const trade of trades) {
    const snap = trade.get('buyOrder') || {};
    const orderId = String(trade.get('buyOrderId') || snap.objectId || snap.id || '').trim();
    const order = orderById.get(orderId);
    if (!order) continue;

    const legType = String(order.get('legType') || '').trim();
    if (legType && !trade.get('buyLegType')) {
      trade.set('buyLegType', legType);
    }
    const pairExecutionId = String(order.get('pairExecutionId') || '').trim();
    if (pairExecutionId && !trade.get('pairExecutionId')) {
      trade.set('pairExecutionId', pairExecutionId);
    }

    const enrichedSnap = {
      ...snap,
      isMirrorPoolOrder: snap.isMirrorPoolOrder === true || order.get('isMirrorPoolOrder') === true,
      legType: snap.legType || legType || null,
    };
    trade.set('buyOrder', enrichedSnap);
  }

  return trades;
}

module.exports = {
  normalizeTradeForClient,
  normalizeBuyOrderSnapshot,
  enrichTradesWithOrderLegs,
  isoOrNow,
};
