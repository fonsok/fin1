'use strict';

const { persistMarketDataRow } = require('../utils/marketDataFeed/persistMarketDataRow');

/**
 * Trader-published indicative quote (append-only MarketData).
 * Interim bridge until feed-only path is default; server execution still reads MarketData only.
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

  return persistMarketDataRow({
    symbol: key,
    price: numericPrice,
    exchange: 'FIN1',
    timestamp: new Date(),
  });
}

module.exports = {
  handleUpsertMarketDataQuote,
};
