'use strict';

const { round4, fetchLatestMarketDataPrice } = require('../executionPriceResolver');
const { getMockSymbol, listMockSymbols, hashString } = require('./mockSymbolCatalog');

const DEFAULT_DISCOVERED_BASE_PRICE = 150.0;

function defaultBasePriceForSymbol(symbol) {
  const key = String(symbol || '').trim();
  if (!key) {
    return DEFAULT_DISCOVERED_BASE_PRICE;
  }
  const hash = hashString(key);
  // Deterministic demo price in 50–500 EUR (aligned with iOS mock stock range).
  return round4(50 + (hash % 45001) / 100);
}

function syntheticFeedEntry(symbol, basePrice, label = 'discovered') {
  const key = String(symbol || '').trim();
  return {
    symbol: key,
    basePrice: round4(basePrice),
    exchange: 'FIN1',
    label,
  };
}

async function resolveFeedEntry(symbol) {
  const key = String(symbol || '').trim();
  if (!key) {
    return null;
  }

  const catalogEntry = getMockSymbol(key);
  if (catalogEntry) {
    return { ...catalogEntry };
  }

  const lastQuote = await fetchLatestMarketDataPrice(key);
  if (lastQuote?.price > 0) {
    return syntheticFeedEntry(key, lastQuote.price, 'last_market_data');
  }

  return syntheticFeedEntry(key, defaultBasePriceForSymbol(key), 'synthetic_default');
}

/**
 * Catalog + recently traded symbols, each with a resolvable base price.
 */
async function buildFeedRefreshEntries({ symbols = null } = {}) {
  const keys = new Set();

  if (Array.isArray(symbols) && symbols.length > 0) {
    symbols.forEach((symbol) => {
      const key = String(symbol || '').trim();
      if (key) keys.add(key);
    });
  } else {
    listMockSymbols().forEach((entry) => keys.add(entry.symbol));
    const { discoverActiveMarketSymbols } = require('./discoverActiveMarketSymbols');
    const discovered = await discoverActiveMarketSymbols();
    discovered.forEach((symbol) => keys.add(symbol));
  }

  const entries = [];
  for (const key of keys) {
    const entry = await resolveFeedEntry(key);
    if (entry) {
      entries.push(entry);
    }
  }
  return entries;
}

module.exports = {
  resolveFeedEntry,
  buildFeedRefreshEntries,
  defaultBasePriceForSymbol,
  syntheticFeedEntry,
};
