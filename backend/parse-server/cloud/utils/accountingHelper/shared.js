'use strict';

function round2(n) {
  return Math.round(n * 100) / 100;
}

function round4(n) {
  return Math.round(n * 10000) / 10000;
}

function formatDateCompact(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}${m}${d}`;
}

function generateShortHash() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let hash = '';
  for (let i = 0; i < 8; i++) {
    hash += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return hash;
}

/** Stückpreis für Investor-Buy-Leg (entryPrice, buyOrder.price, oder Amount/Qty). */
function resolveTradeBuyPrice(trade) {
  if (!trade || typeof trade.get !== 'function') return 0;
  const direct = Number(trade.get('entryPrice') || trade.get('buyPrice') || 0);
  if (Number.isFinite(direct) && direct > 0) return direct;

  const buyOrder = trade.get('buyOrder') || {};
  const fromOrder = Number(buyOrder.price || buyOrder.limitPrice || 0);
  if (Number.isFinite(fromOrder) && fromOrder > 0) return fromOrder;

  const buyAmount = Number(trade.get('buyAmount') || buyOrder.totalAmount || 0);
  const qty = Number(trade.get('quantity') || buyOrder.quantity || 0);
  if (Number.isFinite(buyAmount) && buyAmount > 0 && Number.isFinite(qty) && qty > 0) {
    return round2(buyAmount / qty);
  }
  return 0;
}

/** Stückpreis Verkauf (exitPrice, sellOrder(s).price, oder totalAmount/quantity). */
/** Settlement: pool mirror trade first, trader leg fallback when sell not yet mirrored. */
function resolveSettlementLegPrices(poolTrade, traderTrade) {
  let tradeBuyPrice = resolveTradeBuyPrice(poolTrade);
  let tradeSellPrice = resolveTradeSellPrice(poolTrade);
  const trader = traderTrade && poolTrade && traderTrade.id !== poolTrade.id ? traderTrade : null;
  if (trader) {
    if (!(tradeSellPrice > 0)) tradeSellPrice = resolveTradeSellPrice(trader);
    if (!(tradeBuyPrice > 0)) tradeBuyPrice = resolveTradeBuyPrice(trader);
  }
  return { tradeBuyPrice, tradeSellPrice };
}

function resolveTradeSellPrice(trade) {
  if (!trade || typeof trade.get !== 'function') return 0;
  const direct = Number(trade.get('exitPrice') || trade.get('sellPrice') || 0);
  if (Number.isFinite(direct) && direct > 0) return direct;

  const sellOrders = trade.get('sellOrders') || [];
  const sellOne = trade.get('sellOrder');
  const orders = sellOrders.length > 0 ? sellOrders : (sellOne ? [sellOne] : []);

  for (const o of orders) {
    if (!o || typeof o !== 'object') continue;
    const fromFields = Number(o.price || o.limitPrice || o.averagePrice || 0);
    if (Number.isFinite(fromFields) && fromFields > 0) return fromFields;
    const qty = Number(o.quantity || 0);
    const total = Number(o.totalAmount || 0);
    if (Number.isFinite(qty) && qty > 0 && Number.isFinite(total) && total > 0) {
      return round2(total / qty);
    }
  }
  return 0;
}

module.exports = {
  round2,
  round4,
  formatDateCompact,
  generateShortHash,
  resolveTradeBuyPrice,
  resolveTradeSellPrice,
  resolveSettlementLegPrices,
};
