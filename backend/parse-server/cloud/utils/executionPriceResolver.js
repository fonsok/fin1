'use strict';

const { loadConfig } = require('./configHelper/index.js');

function round4(value) {
  return Math.round(Number(value) * 10000) / 10000;
}

function absBpsDiff(reference, candidate) {
  if (!(reference > 0) || !(candidate > 0)) return Infinity;
  return (Math.abs(reference - candidate) / reference) * 10000;
}

async function fetchLatestMarketDataPrice(symbol) {
  const key = String(symbol || '').trim();
  if (!key) return null;

  const query = new Parse.Query('MarketData');
  query.equalTo('symbol', key);
  query.descending('timestamp');
  query.limit(1);
  const row = await query.first({ useMasterKey: true });
  if (!row) return null;

  const price = Number(row.get('price'));
  const rawTs = row.get('timestamp');
  const timestamp = rawTs instanceof Date ? rawTs : new Date(rawTs);
  if (!Number.isFinite(price) || price <= 0 || Number.isNaN(timestamp.getTime())) {
    return null;
  }

  return { price, timestamp };
}

/**
 * Authoritative execution price (server-side SSOT, intent-only).
 * Market orders: fresh Parse MarketData only — no client price fallback.
 * Limit orders: limitPrice only.
 */
async function resolvePairedBuyExecutionPrice({
  symbol,
  orderInstruction = 'market',
  limitPrice = null,
}) {
  const config = await loadConfig(true);
  const limits = config.limits || {};
  const marketDataMaxAgeSec = Number(limits.executionPriceMarketDataMaxAgeSeconds ?? 300);

  const instruction = String(orderInstruction).toLowerCase();

  if (instruction === 'limit') {
    const lp = Number(limitPrice);
    if (!Number.isFinite(lp) || lp <= 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'valid limitPrice required for limit orders');
    }
    return {
      executionPrice: round4(lp),
      priceSource: 'limit_price',
      clientSubmittedPrice: null,
      serverReferencePrice: round4(lp),
      priceSnapshotAt: new Date().toISOString(),
      clientQuotedAt: null,
    };
  }

  if (!['market'].includes(instruction)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'orderInstruction must be market or limit');
  }

  const marketSnap = await fetchLatestMarketDataPrice(symbol);
  if (!marketSnap) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'no market data for symbol — cannot execute market order',
    );
  }

  const mdAgeMs = Date.now() - marketSnap.timestamp.getTime();
  if (mdAgeMs > marketDataMaxAgeSec * 1000) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'market data stale — refresh and retry',
    );
  }

  return {
    executionPrice: round4(marketSnap.price),
    priceSource: 'server_market_data',
    clientSubmittedPrice: null,
    serverReferencePrice: round4(marketSnap.price),
    priceSnapshotAt: marketSnap.timestamp.toISOString(),
    clientQuotedAt: null,
  };
}

function orderTypeToInstruction(orderType) {
  const type = String(orderType || 'market').toLowerCase();
  return ['limit', 'stop_limit'].includes(type) ? 'limit' : 'market';
}

/**
 * Shared resolver for placeOrder and Order beforeSave (trader-only buys/sells).
 */
async function resolveOrderExecutionPrice({
  symbol,
  orderType = 'market',
  limitPrice = null,
}) {
  const instruction = orderTypeToInstruction(orderType);
  return resolvePairedBuyExecutionPrice({
    symbol,
    orderInstruction: instruction,
    limitPrice: instruction === 'limit' ? limitPrice : null,
  });
}

function applyExecutionPriceMetaToOrder(order, priceMeta) {
  order.set('price', priceMeta.executionPrice);
  order.set('executionPriceSource', priceMeta.priceSource);
  if (priceMeta.clientSubmittedPrice != null) {
    order.set('clientSubmittedPrice', priceMeta.clientSubmittedPrice);
  }
  if (priceMeta.serverReferencePrice != null) {
    order.set('serverReferencePrice', priceMeta.serverReferencePrice);
  }
  if (priceMeta.priceSnapshotAt) {
    order.set('priceSnapshotAt', priceMeta.priceSnapshotAt);
  }
  if (priceMeta.clientQuotedAt) {
    order.set('clientQuotedAt', priceMeta.clientQuotedAt);
  }
  const qty = Number(order.get('quantity') || 0);
  if (qty > 0) {
    order.set('grossAmount', qty * priceMeta.executionPrice);
  }
}

module.exports = {
  resolvePairedBuyExecutionPrice,
  resolveOrderExecutionPrice,
  applyExecutionPriceMetaToOrder,
  orderTypeToInstruction,
  round4,
  absBpsDiff,
  fetchLatestMarketDataPrice,
};
