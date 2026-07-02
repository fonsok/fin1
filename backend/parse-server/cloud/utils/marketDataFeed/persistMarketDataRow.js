'use strict';

const { round4 } = require('../executionPriceResolver');

/**
 * Append-only MarketData row (SSOT input for executionPriceResolver).
 */
async function persistMarketDataRow({
  symbol,
  price,
  exchange = 'FIN1',
  timestamp = new Date(),
}) {
  const key = String(symbol || '').trim();
  const numericPrice = Number(price);
  if (!key) {
    throw new Error('symbol required');
  }
  if (!Number.isFinite(numericPrice) || numericPrice <= 0) {
    throw new Error('valid price required');
  }

  const publishedAt = timestamp instanceof Date ? timestamp : new Date(timestamp);
  const roundedPrice = round4(numericPrice);

  const row = new Parse.Object('MarketData');
  row.set('symbol', key);
  row.set('price', roundedPrice);
  row.set('exchange', String(exchange || 'FIN1'));
  row.set('timestamp', publishedAt);
  await row.save(null, { useMasterKey: true });

  return {
    symbol: key,
    price: roundedPrice,
    exchange: String(exchange || 'FIN1'),
    publishedAt: publishedAt.toISOString(),
  };
}

module.exports = {
  persistMarketDataRow,
};
