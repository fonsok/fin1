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
 * Authoritative execution price for paired buy (server-side SSOT).
 * Limit orders use limitPrice; market orders prefer fresh MarketData, else validated client quote.
 */
async function resolvePairedBuyExecutionPrice({
  symbol,
  orderInstruction = 'market',
  limitPrice = null,
  clientPrice,
  clientQuotedAt = null,
}) {
  const config = await loadConfig(true);
  const limits = config.limits || {};
  const maxQuoteAgeSec = Number(limits.executionPriceMaxQuoteAgeSeconds ?? 30);
  const marketDataMaxAgeSec = Number(limits.executionPriceMarketDataMaxAgeSeconds ?? 300);
  const toleranceBps = Number(limits.executionPriceToleranceBps ?? 100);

  const instruction = String(orderInstruction).toLowerCase();
  const submittedClientPrice = Number(clientPrice);

  if (instruction === 'limit') {
    const lp = Number(limitPrice);
    if (!Number.isFinite(lp) || lp <= 0) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'valid limitPrice required for limit orders');
    }
    return {
      executionPrice: round4(lp),
      priceSource: 'limit_price',
      clientSubmittedPrice: Number.isFinite(submittedClientPrice) ? round4(submittedClientPrice) : null,
      serverReferencePrice: round4(lp),
      priceSnapshotAt: new Date().toISOString(),
      clientQuotedAt: null,
    };
  }

  if (!['market'].includes(instruction)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'orderInstruction must be market or limit');
  }

  let quoteAt = null;
  if (clientQuotedAt != null && clientQuotedAt !== '') {
    quoteAt = new Date(clientQuotedAt);
    if (Number.isNaN(quoteAt.getTime())) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'invalid clientQuotedAt');
    }
    const ageMs = Date.now() - quoteAt.getTime();
    if (ageMs > maxQuoteAgeSec * 1000) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        'price quote expired — refresh market data and retry',
      );
    }
    if (ageMs < -5000) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'clientQuotedAt must not be in the future');
    }
  }

  const marketSnap = await fetchLatestMarketDataPrice(symbol);
  if (marketSnap) {
    const mdAgeMs = Date.now() - marketSnap.timestamp.getTime();
    if (mdAgeMs <= marketDataMaxAgeSec * 1000) {
      if (Number.isFinite(submittedClientPrice) && submittedClientPrice > 0) {
        if (absBpsDiff(marketSnap.price, submittedClientPrice) > toleranceBps) {
          throw new Parse.Error(
            Parse.Error.INVALID_VALUE,
            `client price does not match server MarketData (reference=${round4(marketSnap.price)})`,
          );
        }
      }
      return {
        executionPrice: round4(marketSnap.price),
        priceSource: 'server_market_data',
        clientSubmittedPrice: Number.isFinite(submittedClientPrice) ? round4(submittedClientPrice) : null,
        serverReferencePrice: round4(marketSnap.price),
        priceSnapshotAt: marketSnap.timestamp.toISOString(),
        clientQuotedAt: quoteAt ? quoteAt.toISOString() : null,
      };
    }
  }

  if (!Number.isFinite(submittedClientPrice) || submittedClientPrice <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'valid price required');
  }

  return {
    executionPrice: round4(submittedClientPrice),
    priceSource: 'client_quote_validated',
    clientSubmittedPrice: round4(submittedClientPrice),
    serverReferencePrice: marketSnap ? round4(marketSnap.price) : null,
    priceSnapshotAt: new Date().toISOString(),
    clientQuotedAt: quoteAt ? quoteAt.toISOString() : null,
  };
}

function orderTypeToInstruction(orderType) {
  const type = String(orderType || 'market').toLowerCase();
  return ['limit', 'stop_limit'].includes(type) ? 'limit' : 'market';
}

/**
 * Shared resolver for placeOrder and Order beforeSave (trader-only buys).
 */
async function resolveOrderExecutionPrice({
  symbol,
  orderType = 'market',
  limitPrice = null,
  clientPrice,
  clientQuotedAt = null,
}) {
  const instruction = orderTypeToInstruction(orderType);
  return resolvePairedBuyExecutionPrice({
    symbol,
    orderInstruction: instruction,
    limitPrice: instruction === 'limit' ? (limitPrice ?? clientPrice) : null,
    clientPrice,
    clientQuotedAt,
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
