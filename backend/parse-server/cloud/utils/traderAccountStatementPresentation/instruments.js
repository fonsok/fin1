'use strict';

const { tradeStatementTitle } = require('./instrumentTitles');
const {
  parseOrderToSnapshot,
  resolveOrderForTradeSide,
} = require('./orderContext');

/**
 * SSOT aligned with `buildSellOrderSnapshotFromOrder`: use executed qty when > 0,
 * else order qty. Returns null when no positive quantity (so callers can fall through).
 */
function resolveOrderQuantity(orderLike) {
  if (!orderLike) return null;
  const parsed = Number(orderLike.executedQuantity || orderLike.quantity);
  if (!Number.isFinite(parsed) || parsed <= 0) return null;
  return parsed;
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

function parseInstrumentFromTrade(trade, order, opts = {}) {
  const transactionType = String(opts.transactionType || '').toLowerCase();
  const parseOrderSnap = order?.get ? parseOrderToSnapshot(order) : null;
  const sellOrderHint = opts.sellOrder || (transactionType === 'sell' ? parseOrderSnap : null) || null;
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

function formatStrikePrice(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';
  return /^strike\b/i.test(raw) ? raw : `Strike ${raw}`;
}

function parseInstrumentFromInvoice(invoice) {
  const lineItems = invoice.get('lineItems') || [];
  const primary = lineItems.find((item) => String(item?.itemType || '') === 'securities')
    || lineItems[0];
  if (!primary) {
    return {
      wknOrIsin: '',
      securitiesDirection: '',
      underlyingAsset: '',
      strikePrice: '',
      issuer: '',
      quantity: '',
    };
  }

  const structuredWkn = String(primary.wkn || '').trim();
  const structuredDirection = String(primary.optionDirection || '').trim();
  const structuredUnderlying = String(primary.underlyingAsset || '').trim();
  const structuredStrike = formatStrikePrice(primary.strikePrice);
  const structuredIssuer = String(primary.issuer || '').trim();
  const structuredSymbol = String(primary.symbol || '').trim();

  if (structuredWkn || structuredDirection || structuredUnderlying) {
    const wknOrIsin = structuredWkn || structuredSymbol;
    return {
      wknOrIsin,
      securitiesDirection: structuredDirection,
      underlyingAsset: resolveUnderlyingAsset([structuredUnderlying], wknOrIsin),
      strikePrice: structuredStrike,
      issuer: structuredIssuer,
      quantity: primary.quantity != null ? String(primary.quantity) : '',
    };
  }

  const description = String(primary.description || '').trim();
  const components = description
    .split(' - ')
    .map((part) => part.trim())
    .filter(Boolean);

  const wknOrIsin = components[0] || '';
  const strikePart = components.find((part) => /^strike\b/i.test(part)) || '';
  const underlyingAsset = resolveUnderlyingAsset(
    components.slice(2).filter((part) => part !== strikePart),
    wknOrIsin,
  );

  return {
    wknOrIsin,
    securitiesDirection: components[1] || '',
    underlyingAsset,
    strikePrice: strikePart || formatStrikePrice(components[3]),
    issuer: components[4] || '',
    quantity: primary.quantity != null ? String(primary.quantity) : '',
  };
}

function positiveQuantityString(value) {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed > 0) return String(parsed);
  return '';
}

function mergeInstrumentFields(tradeInstrument, fallback = {}) {
  return {
    wknOrIsin: tradeInstrument.wknOrIsin || fallback.wknOrIsin || '',
    securitiesDirection: tradeInstrument.securitiesDirection || fallback.securitiesDirection || '',
    underlyingAsset: tradeInstrument.underlyingAsset || fallback.underlyingAsset || '',
    strikePrice: tradeInstrument.strikePrice || fallback.strikePrice || '',
    issuer: tradeInstrument.issuer || fallback.issuer || '',
    quantity: positiveQuantityString(tradeInstrument.quantity)
      || positiveQuantityString(fallback.quantity)
      || '',
  };
}

function resolveInstrumentForDisplayEvent(trade, order, transactionType, fallback = {}, opts = {}) {
  if (!trade && !order) {
    return { ...fallback };
  }
  const fromTrade = parseInstrumentFromTrade(trade, order, {
    transactionType,
    sellOrder: opts.sellOrder || null,
  });
  return mergeInstrumentFields(fromTrade, fallback);
}

function shouldEnrichTimelineEvent(event) {
  if (!event.tradeId || !event.transactionTypeLabel) return false;
  if (event.instrumentResolvedFromTrade) return false;
  return true;
}

function enrichTimelineWithTradeInstruments(timeline, instrumentContext = {}) {
  const { tradeById = new Map() } = instrumentContext;
  return timeline.map((event) => {
    if (!shouldEnrichTimelineEvent(event)) {
      return event;
    }
    const trade = tradeById.get(event.tradeId);
    const order = resolveOrderForTradeSide(instrumentContext, event.tradeId, event.transactionTypeLabel, {
      orderId: event.orderId,
      trade,
    });
    if (!trade && !order) return event;

    const sellOrder = event.transactionTypeLabel === 'sell'
      ? (order?.get ? parseOrderToSnapshot(order) : order)
      : null;
    const instrument = resolveInstrumentForDisplayEvent(trade, order, event.transactionTypeLabel, {
      wknOrIsin: event.wknOrIsin,
      underlyingAsset: event.underlyingAsset,
      securitiesDirection: event.securitiesDirection,
      quantity: event.quantity,
      strikePrice: event.strikePrice,
      issuer: event.issuer,
    }, { sellOrder });

    if (!instrument.wknOrIsin && !instrument.securitiesDirection && !instrument.underlyingAsset) {
      return event;
    }
    return {
      ...event,
      wknOrIsin: instrument.wknOrIsin || null,
      underlyingAsset: instrument.underlyingAsset || null,
      securitiesDirection: instrument.securitiesDirection || null,
      quantity: instrument.quantity || null,
      strikePrice: instrument.strikePrice || null,
      issuer: instrument.issuer || null,
      statementTitle: tradeStatementTitle(event.transactionTypeLabel, instrument),
      instrumentResolvedFromTrade: true,
    };
  });
}

module.exports = {
  parseInstrumentFromTrade,
  parseInstrumentFromInvoice,
  resolveInstrumentForDisplayEvent,
  shouldEnrichTimelineEvent,
  enrichTimelineWithTradeInstruments,
};
