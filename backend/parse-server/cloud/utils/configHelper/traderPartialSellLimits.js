'use strict';

const { loadConfig } = require('./loadConfig');
const { peekCacheOrNull } = require('./cache');
const {
  deriveSoldQuantity,
  resolveSellOrdersFromTradeLike,
} = require('../../triggers/tradeSellQuantityHelpers');

const QTY_EPS = 1e-6;

/**
 * @returns {Promise<number>} 0–3 (admin `maxTraderPartialSells`)
 */
function maxFromConfigObject(config) {
  const raw = config && config.financial ? config.financial.maxTraderPartialSells : undefined;
  const n = Math.floor(Number(raw));
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.min(3, n);
}

async function getMaxTraderPartialSells() {
  const cached = peekCacheOrNull();
  if (cached) return maxFromConfigObject(cached);
  const config = await loadConfig();
  return maxFromConfigObject(config);
}

function buyQuantityFromTrade(trade) {
  const buyOrder = trade.get ? (trade.get('buyOrder') || {}) : (trade.buyOrder || {});
  return Number(
    (trade.get ? trade.get('quantity') : trade.quantity)
    || buyOrder.quantity
    || 0,
  );
}

/**
 * Anzahl Teil-Verkaufs-Ereignisse (Verkäufe vor vollständigem Exit).
 * @param {Parse.Object|object} trade
 */
function countTraderPartialSellEvents(trade) {
  const sells = resolveSellOrdersFromTradeLike(trade);
  if (!sells.length) return 0;
  const buyQty = buyQuantityFromTrade(trade);
  const soldQty = trade.get ? deriveSoldQuantity(trade) : deriveSoldQuantity({ get: (k) => trade[k] });
  if (!(buyQty > 0)) return sells.length;
  if (soldQty >= buyQty - QTY_EPS) {
    return Math.max(0, sells.length - 1);
  }
  return sells.length;
}

/**
 * @param {Parse.Object} trade
 * @param {Parse.Object|null} previousTrade
 * @param {number} [maxOverride]
 */
async function assertTraderPartialSellWithinLimit(trade, previousTrade, maxOverride) {
  const max = Number.isFinite(maxOverride)
    ? Math.min(3, Math.max(0, Math.floor(maxOverride)))
    : await getMaxTraderPartialSells();

  const prevCount = previousTrade ? countTraderPartialSellEvents(previousTrade) : 0;
  const newCount = countTraderPartialSellEvents(trade);
  if (newCount <= prevCount) return;

  const buyQty = buyQuantityFromTrade(trade);
  const soldQty = deriveSoldQuantity(trade);

  if (max === 0) {
    if (buyQty > 0 && soldQty < buyQty - QTY_EPS) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Teil-Verkäufe sind deaktiviert (Konfiguration maxTraderPartialSells=0). '
        + 'Bitte die gesamte Restposition in einem Verkauf ausführen.',
      );
    }
    const sells = resolveSellOrdersFromTradeLike(trade);
    if (sells.length > 1) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'Teil-Verkäufe sind deaktiviert — nur ein vollständiger Verkauf ist erlaubt.',
      );
    }
    return;
  }

  if (newCount > max) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      `Maximal ${max} Teil-Verkauf${max === 1 ? '' : 'e'} pro Trade erlaubt (Konfiguration maxTraderPartialSells).`,
    );
  }
}

module.exports = {
  getMaxTraderPartialSells,
  countTraderPartialSellEvents,
  assertTraderPartialSellWithinLimit,
};
