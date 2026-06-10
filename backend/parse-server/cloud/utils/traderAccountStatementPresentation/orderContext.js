'use strict';

const { round2 } = require('../accountingHelper/shared');
const {
  getOrderArrayFromTradeLike,
  resolveSellOrderNetCashAmount,
} = require('../accountingHelper/settlementTradeMath');

/** One trade → one buy order; zero or more sell orders (partial sells). */
function buildOrderMapsFromParseOrders(orders) {
  const buyOrderByTradeId = new Map();
  const sellOrdersByTradeId = new Map();
  for (const order of orders) {
    const tradeId = String(order.get('tradeId') || '').trim();
    if (!tradeId) continue;
    const side = String(order.get('side') || '').toLowerCase();
    if (side === 'sell') {
      if (!sellOrdersByTradeId.has(tradeId)) sellOrdersByTradeId.set(tradeId, []);
      sellOrdersByTradeId.get(tradeId).push(order);
    } else if (!buyOrderByTradeId.has(tradeId)) {
      buyOrderByTradeId.set(tradeId, order);
    }
  }
  return { buyOrderByTradeId, sellOrdersByTradeId };
}

function parseOrderToSnapshot(order) {
  if (!order) return null;
  if (!order.get) return order;
  const grossAmount = Number(order.get('grossAmount') || order.get('totalAmount') || 0);
  return {
    id: order.id,
    objectId: order.id,
    orderId: order.id,
    wkn: order.get('wkn'),
    symbol: order.get('symbol'),
    optionDirection: order.get('optionDirection'),
    underlyingAsset: order.get('underlyingAsset'),
    strikePrice: order.get('strikePrice'),
    issuer: order.get('issuer'),
    quantity: order.get('quantity'),
    executedQuantity: order.get('executedQuantity'),
    totalAmount: grossAmount,
    grossAmount,
    netAmount: order.get('netAmount'),
    side: order.get('side'),
    legType: order.get('legType'),
  };
}

function resolveSellOrderNetCashFromOrderLike(order, feeConfig = {}) {
  if (order?.get) {
    const net = Number(order.get('netAmount') || 0);
    if (net > 0) return round2(net);
    return resolveSellOrderNetCashAmount(parseOrderToSnapshot(order), feeConfig);
  }
  return resolveSellOrderNetCashAmount(order, feeConfig);
}

function findSellOrderByNetCash(sellOrders, legAmount, feeConfig = {}) {
  if (!sellOrders.length || !(legAmount > 0)) return null;
  return sellOrders.find((sellOrder) => (
    Math.abs(resolveSellOrderNetCashFromOrderLike(sellOrder, feeConfig) - legAmount) < 0.02
  )) || null;
}

function resolveSellOrderCandidates(trade, parseSellOrders = []) {
  if (parseSellOrders.length > 0) {
    return parseSellOrders.map(parseOrderToSnapshot);
  }
  return getOrderArrayFromTradeLike(trade);
}

function resolveSellOrderForStatementLeg(trade, leg, feeConfig = {}, parseSellOrders = []) {
  const candidates = resolveSellOrderCandidates(trade, parseSellOrders);
  if (!candidates.length) return null;
  if (candidates.length === 1) return candidates[0];

  const legAmount = Math.abs(Number(leg?.get?.('amount') || 0));
  if (legAmount > 0) {
    const parseMatch = findSellOrderByNetCash(parseSellOrders, legAmount, feeConfig);
    if (parseMatch) return parseOrderToSnapshot(parseMatch);
    const embeddedMatch = candidates.find((sellOrder) => {
      const netCash = resolveSellOrderNetCashAmount(sellOrder, feeConfig);
      return Math.abs(netCash - legAmount) < 0.02;
    });
    if (embeddedMatch) return embeddedMatch;
  }

  return candidates[candidates.length - 1];
}

function resolveOrderForTradeSide(instrumentContext, tradeId, transactionType, opts = {}) {
  const {
    buyOrderByTradeId = new Map(),
    sellOrdersByTradeId = new Map(),
  } = instrumentContext;
  const tx = String(transactionType || '').toLowerCase();
  const tid = String(tradeId || '').trim();
  if (!tid) return null;

  if (tx === 'sell') {
    const parseSells = sellOrdersByTradeId.get(tid) || [];
    if (opts.orderId) {
      const byInvoiceOrder = parseSells.find((order) => order.id === opts.orderId);
      if (byInvoiceOrder) return byInvoiceOrder;
    }
    if (opts.stmtLeg) {
      return resolveSellOrderForStatementLeg(
        opts.trade,
        opts.stmtLeg,
        opts.feeConfig,
        parseSells,
      );
    }
    return parseSells.length > 0 ? parseSells[parseSells.length - 1] : null;
  }

  return buyOrderByTradeId.get(tid) || null;
}

module.exports = {
  buildOrderMapsFromParseOrders,
  parseOrderToSnapshot,
  resolveSellOrderNetCashFromOrderLike,
  findSellOrderByNetCash,
  resolveSellOrderForStatementLeg,
  resolveOrderForTradeSide,
};
