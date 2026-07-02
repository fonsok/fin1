'use strict';

const { round4 } = require('../utils/executionPriceResolver');

/**
 * Publishes an indicative quote into Parse MarketData (append-only row).
 * Execution still reads MarketData via resolvePairedBuyExecutionPrice — no client price in execute payloads.
 * Interim bridge until a server-side market-data feed exists (ADR-019 Phase 8).
 */
async function handleUpsertMarketDataQuote(request) {
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader role required');
  }

  const { symbol, price } = request.params || {};
  const key = String(symbol || '').trim();
  if (!key) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'symbol required');
  }

  const numericPrice = Number(price);
  if (!Number.isFinite(numericPrice) || numericPrice <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'valid price required');
  }

  const publishedAt = new Date();
  const roundedPrice = round4(numericPrice);

  const row = new Parse.Object('MarketData');
  row.set('symbol', key);
  row.set('price', roundedPrice);
  row.set('exchange', 'FIN1');
  row.set('timestamp', publishedAt);
  await row.save(null, { useMasterKey: true });

  return {
    symbol: key,
    price: roundedPrice,
    publishedAt: publishedAt.toISOString(),
  };
}

module.exports = {
  handleUpsertMarketDataQuote,
};
