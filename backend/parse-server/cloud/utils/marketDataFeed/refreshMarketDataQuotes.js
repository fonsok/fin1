'use strict';

const { loadConfig } = require('../configHelper/index.js');
const { quotePriceForSymbol } = require('./mockSymbolCatalog');
const { buildFeedRefreshEntries } = require('./feedEntryResolver');
const { persistMarketDataRow } = require('./persistMarketDataRow');

const DEFAULT_INTERVAL_SECONDS = 60;
const MIN_INTERVAL_SECONDS = 15;
const MAX_INTERVAL_SECONDS = 3600;

function envFeedDisabled() {
  return String(process.env.MARKET_DATA_FEED_ENABLED || '').trim() === '0';
}

function clampIntervalSeconds(raw) {
  const n = Number(raw);
  if (!Number.isFinite(n)) {
    return DEFAULT_INTERVAL_SECONDS;
  }
  return Math.min(MAX_INTERVAL_SECONDS, Math.max(MIN_INTERVAL_SECONDS, Math.floor(n)));
}

async function isMarketDataFeedEnabled() {
  if (envFeedDisabled()) {
    return false;
  }
  const config = await loadConfig(true);
  const display = config.display || {};
  return display.marketDataFeedEnabled !== false;
}

async function getMarketDataFeedIntervalMs() {
  if (envFeedDisabled()) {
    return 0;
  }
  try {
    const config = await loadConfig(true);
    const display = config.display || {};
    if (display.marketDataFeedEnabled === false) {
      return 0;
    }
    return clampIntervalSeconds(display.marketDataFeedIntervalSeconds) * 1000;
  } catch (_err) {
    return DEFAULT_INTERVAL_SECONDS * 1000;
  }
}

async function refreshMarketDataQuotes({ symbols = null } = {}) {
  const enabled = await isMarketDataFeedEnabled();
  if (!enabled) {
    return { enabled: false, refreshed: 0, symbols: [] };
  }

  const now = new Date();
  const entries = await buildFeedRefreshEntries({
    symbols: Array.isArray(symbols) && symbols.length > 0 ? symbols : null,
  });

  const results = [];
  for (const entry of entries) {
    const price = quotePriceForSymbol(entry, now);
    if (!(price > 0)) {
      continue;
    }
    const saved = await persistMarketDataRow({
      symbol: entry.symbol,
      price,
      exchange: entry.exchange || 'Xetra',
      timestamp: now,
    });
    results.push(saved);
  }

  return {
    enabled: true,
    refreshed: results.length,
    symbols: results.map((row) => row.symbol),
    refreshedAt: now.toISOString(),
  };
}

module.exports = {
  refreshMarketDataQuotes,
  isMarketDataFeedEnabled,
  getMarketDataFeedIntervalMs,
  DEFAULT_INTERVAL_SECONDS,
};
