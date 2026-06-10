'use strict';

const { round2 } = require('../shared');
const {
  getOrderArrayFromTradeLike,
  resolveSellOrderKey,
} = require('../settlementTradeMath');

function sellOrderTimestamp(order) {
  const candidates = [order?.executedAt, order?.createdAt].filter(Boolean);
  for (const raw of candidates) {
    const t = new Date(raw).getTime();
    if (!Number.isNaN(t)) return t;
  }
  return 0;
}

function resolveSellOrderId(order, orderLike) {
  return String(
    orderLike?.id
    || order?.id
    || order?.objectId
    || order?.orderId
    || '',
  ).trim();
}

function sellOrderQuantity(orderLike) {
  const q = Number(orderLike?.quantity || orderLike?.executedQuantity || 0);
  return q > 0 ? round2(q) : 0;
}

function sortSellOrdersChronologically(orders) {
  return [...orders].sort((a, b) => {
    const ta = sellOrderTimestamp(a);
    const tb = sellOrderTimestamp(b);
    if (ta !== tb) return ta - tb;
    return resolveSellOrderKey(a).localeCompare(resolveSellOrderKey(b));
  });
}

function toIsoTimestamp(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/**
 * Chronological partial-sell context for one sell TSC at booking time.
 * Cumulative quantity = sum of sell orders up to and including this leg (not later sells).
 */
function buildPartialSellSnapshot({
  trade,
  order,
  orderLike,
  sellOrderId,
  buyQty,
  tradeStatus,
}) {
  const allSells = sortSellOrdersChronologically(getOrderArrayFromTradeLike(trade));
  const currentId = String(sellOrderId || resolveSellOrderId(order, orderLike) || '').trim();
  let eventIndex = null;
  let cumulativeSoldQty = 0;
  let orderSoldQty = sellOrderQuantity(orderLike);

  if (currentId && allSells.length) {
    const idx = allSells.findIndex((o) => resolveSellOrderKey(o) === currentId);
    if (idx >= 0) {
      eventIndex = idx + 1;
      cumulativeSoldQty = round2(
        allSells
          .slice(0, idx + 1)
          .reduce((sum, o) => sum + Number(o.quantity || o.executedQuantity || 0), 0),
      );
      if (!(orderSoldQty > 0)) {
        orderSoldQty = round2(Number(allSells[idx].quantity || allSells[idx].executedQuantity || 0));
      }
    }
  }

  if (!(cumulativeSoldQty > 0) && orderSoldQty > 0) {
    cumulativeSoldQty = orderSoldQty;
  }

  const isPartialSell = (buyQty > 0 && cumulativeSoldQty > 0 && cumulativeSoldQty < buyQty)
    || tradeStatus === 'partial';

  if (!isPartialSell) {
    return { isPartialSell: false, partialSell: null };
  }

  const executedAtRaw = orderLike?.executedAt || orderLike?.createdAt || null;

  return {
    isPartialSell: true,
    partialSell: {
      isPartialSell: true,
      sellOrderId: currentId || null,
      eventIndex,
      totalSellEvents: allSells.length > 0 ? allSells.length : null,
      executedAt: toIsoTimestamp(executedAtRaw),
      orderQuantity: orderSoldQty > 0 ? orderSoldQty : null,
      cumulativeSoldQuantity: cumulativeSoldQty > 0 ? cumulativeSoldQty : null,
      buyQuantity: buyQty > 0 ? buyQty : null,
      remainingQuantity: buyQty > 0 ? round2(Math.max(0, buyQty - cumulativeSoldQty)) : null,
      sellVolumeProgress: buyQty > 0
        ? round2(Math.min(1, cumulativeSoldQty / buyQty))
        : null,
    },
  };
}

/** Sort persisted TSC sell documents by execution time (metadata), not upload order. */
function traderSellBelegChronologyKey(doc) {
  const meta = doc?.get?.('metadata') || doc?.metadata || {};
  const partial = meta.partialSell && typeof meta.partialSell === 'object'
    ? meta.partialSell
    : null;
  if (partial?.executedAt) {
    const t = new Date(partial.executedAt).getTime();
    if (!Number.isNaN(t)) return t;
  }
  if (partial?.eventIndex != null && Number(partial.eventIndex) > 0) {
    return Number(partial.eventIndex) * 1e12;
  }
  const createdAt = doc?.get?.('createdAt') || doc?.createdAt;
  if (createdAt?.getTime) return createdAt.getTime();
  if (createdAt) {
    const t = new Date(createdAt).getTime();
    if (!Number.isNaN(t)) return t;
  }
  return 0;
}

function sortTraderSellBelegeChronologically(docs) {
  return [...docs].sort((a, b) => {
    const ta = traderSellBelegChronologyKey(a);
    const tb = traderSellBelegChronologyKey(b);
    if (ta !== tb) return ta - tb;
    const na = String(a.get?.('accountingDocumentNumber') || a.accountingDocumentNumber || '');
    const nb = String(b.get?.('accountingDocumentNumber') || b.accountingDocumentNumber || '');
    return na.localeCompare(nb);
  });
}

module.exports = {
  sortSellOrdersChronologically,
  buildPartialSellSnapshot,
  traderSellBelegChronologyKey,
  sortTraderSellBelegeChronologically,
};
