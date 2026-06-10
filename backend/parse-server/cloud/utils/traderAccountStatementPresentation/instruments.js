'use strict';

const {
  getOrderArrayFromTradeLike,
  resolveSellOrderNetCashAmount,
} = require('../accountingHelper/settlementTradeMath');
const { tradeStatementTitle } = require('./instrumentTitles');

function resolveOrderQuantity(orderLike) {
  if (!orderLike) return null;
  const qty = orderLike.executedQuantity ?? orderLike.quantity;
  if (qty == null || qty === '') return null;
  const parsed = Number(qty);
  return Number.isFinite(parsed) ? parsed : null;
}

function resolveUnderlyingAsset(candidates, wknOrIsin) {
  const wkn = String(wknOrIsin || '').trim().toUpperCase();
  for (const value of candidates) {
    const candidate = String(value || '').trim();
    if (!candidate) continue;
    if (wkn && candidate.toUpperCase() === wkn) continue;
    return candidate;
  }
  return '';
}

function resolveSellOrderForStatementLeg(trade, leg, feeConfig = {}) {
  const sellOrders = getOrderArrayFromTradeLike(trade);
  if (!sellOrders.length) return null;
  if (sellOrders.length === 1) return sellOrders[0];

  const legAmount = Math.abs(Number(leg?.get?.('amount') || 0));
  if (legAmount > 0) {
    const match = sellOrders.find((sellOrder) => {
      const netCash = resolveSellOrderNetCashAmount(sellOrder, feeConfig);
      return Math.abs(netCash - legAmount) < 0.02;
    });
    if (match) return match;
  }

  return sellOrders[sellOrders.length - 1];
}

function parseInstrumentFromTrade(trade, order, opts = {}) {
  const transactionType = String(opts.transactionType || '').toLowerCase();
  const sellOrderHint = opts.sellOrder || null;
  const buyOrder = trade?.get?.('buyOrder') || {};
  const sellOrder = sellOrderHint || trade?.get?.('sellOrder') || {};
  const sellOrders = trade?.get?.('sellOrders') || [];
  const embeddedOrder = transactionType === 'sell'
    ? ((sellOrder.wkn || sellOrder.symbol) ? sellOrder : null)
      || (sellOrders[0] || null)
      || (buyOrder.wkn || buyOrder.symbol ? buyOrder : null)
    : (buyOrder.wkn || buyOrder.symbol ? buyOrder : null)
      || ((sellOrder.wkn || sellOrder.symbol) ? sellOrder : null)
      || (sellOrders[0] || null);

  const wknOrIsin = String(
    trade?.get?.('wkn')
    || embeddedOrder?.wkn
    || embeddedOrder?.symbol
    || trade?.get?.('symbol')
    || order?.get?.('wkn')
    || order?.get?.('symbol')
    || '',
  ).trim();
  const securitiesDirection = String(
    embeddedOrder?.optionDirection
    || order?.get?.('optionDirection')
    || trade?.get?.('securityType')
    || '',
  ).trim();
  const underlyingAsset = resolveUnderlyingAsset([
    embeddedOrder?.underlyingAsset,
    order?.get?.('underlyingAsset'),
    sellOrder?.underlyingAsset,
    sellOrders[sellOrders.length - 1]?.underlyingAsset,
  ], wknOrIsin);
  const strikePrice = String(
    embeddedOrder?.strikePrice
    || order?.get?.('strikePrice')
    || '',
  ).trim();
  const issuer = String(
    embeddedOrder?.issuer
    || order?.get?.('issuer')
    || trade?.get?.('securityName')
    || '',
  ).trim();

  let quantityValue = null;
  if (transactionType === 'sell') {
    quantityValue = resolveOrderQuantity(sellOrderHint)
      ?? resolveOrderQuantity(sellOrder)
      ?? resolveOrderQuantity(sellOrders[sellOrders.length - 1])
      ?? (order?.get?.('side') === 'sell'
        ? resolveOrderQuantity({
          executedQuantity: order.get('executedQuantity'),
          quantity: order.get('quantity'),
        })
        : null);
  } else {
    quantityValue = trade?.get?.('quantity')
      ?? resolveOrderQuantity(buyOrder)
      ?? resolveOrderQuantity({
        executedQuantity: order?.get?.('executedQuantity'),
        quantity: order?.get?.('quantity'),
      });
  }
  const quantity = quantityValue != null ? String(quantityValue) : '';

  return { wknOrIsin, securitiesDirection, underlyingAsset, strikePrice, issuer, quantity };
}

function parseInstrumentFromInvoice(invoice) {
  const lineItems = invoice.get('lineItems') || [];
  const primary = lineItems.find((item) => String(item?.itemType || '') === 'securities')
    || lineItems[0];
  const description = String(primary?.description || '').trim();
  const components = description
    .split(' - ')
    .map((part) => part.trim())
    .filter(Boolean);

  const instrument = {
    wknOrIsin: components[0] || '',
    securitiesDirection: components[1] || '',
    underlyingAsset: components[2] || '',
    strikePrice: components[3] || '',
    issuer: components[4] || '',
    quantity: primary?.quantity != null ? String(primary.quantity) : '',
  };
  return instrument;
}

function enrichTimelineWithTradeInstruments(timeline, tradeById, orderByTradeId) {
  return timeline.map((event) => {
    if (event.wknOrIsin || !event.tradeId || !event.transactionTypeLabel) {
      return event;
    }
    const trade = tradeById.get(event.tradeId);
    const order = orderByTradeId.get(event.tradeId);
    if (!trade && !order) return event;
    const instrument = parseInstrumentFromTrade(trade, order, {
      transactionType: event.transactionTypeLabel,
    });
    if (!instrument.wknOrIsin && !instrument.securitiesDirection && !instrument.underlyingAsset) {
      return event;
    }
    return {
      ...event,
      wknOrIsin: instrument.wknOrIsin || event.wknOrIsin,
      underlyingAsset: instrument.underlyingAsset || event.underlyingAsset,
      securitiesDirection: instrument.securitiesDirection || event.securitiesDirection,
      quantity: instrument.quantity || event.quantity,
      strikePrice: instrument.strikePrice || event.strikePrice,
      issuer: instrument.issuer || event.issuer,
      statementTitle: tradeStatementTitle(event.transactionTypeLabel, instrument),
    };
  });
}

module.exports = {
  parseInstrumentFromTrade,
  parseInstrumentFromInvoice,
  resolveSellOrderForStatementLeg,
  enrichTimelineWithTradeInstruments,
};
