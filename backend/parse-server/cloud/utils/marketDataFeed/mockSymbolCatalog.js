'use strict';

const { round4 } = require('../executionPriceResolver');

/**
 * Demo/mock symbols aligned with iOS MockDataGenerator stock WKNs (+ E2E smoke WKNs).
 * Server feed writes Parse MarketData for executionPriceResolver (intent-only).
 */
const MOCK_SYMBOL_CATALOG = [
  { symbol: '865985', basePrice: 175.0, exchange: 'Xetra', label: 'Apple' },
  { symbol: '519000', basePrice: 75.0, exchange: 'Xetra', label: 'BMW' },
  { symbol: '881160', basePrice: 220.0, exchange: 'Xetra', label: 'Tesla' },
  { symbol: '594918', basePrice: 380.0, exchange: 'Xetra', label: 'Microsoft' },
  { symbol: '02079K', basePrice: 140.0, exchange: 'Xetra', label: 'Google' },
  { symbol: 'SMOKE-MIN-BUY-WKN', basePrice: 100.0, exchange: 'SMOKE', label: 'Smoke min buy' },
  { symbol: 'SMOKE-DEPOT-LIMIT-WKN', basePrice: 100.0, exchange: 'SMOKE', label: 'Smoke depot limit' },
  { symbol: 'E2E-PAIRED-WKN', basePrice: 100.0, exchange: 'E2E', label: 'E2E paired buy' },
];

function hashString(value) {
  const text = String(value || '');
  let hash = 0;
  for (let i = 0; i < text.length; i += 1) {
    hash = ((hash * 31) + text.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
}

function listMockSymbols() {
  return MOCK_SYMBOL_CATALOG.map((entry) => ({ ...entry }));
}

function getMockSymbol(symbol) {
  const key = String(symbol || '').trim();
  if (!key) return null;
  return MOCK_SYMBOL_CATALOG.find((entry) => entry.symbol === key) || null;
}

/** Small deterministic jitter (±1%) per symbol and minute bucket. */
function quotePriceForSymbol(entry, asOf = new Date()) {
  const base = Number(entry?.basePrice);
  if (!Number.isFinite(base) || base <= 0) {
    return null;
  }
  const bucket = Math.floor(asOf.getTime() / 60000);
  const seed = hashString(entry.symbol) + bucket;
  const jitterBps = (seed % 201) - 100;
  return round4(base * (1 + jitterBps / 10000));
}

module.exports = {
  MOCK_SYMBOL_CATALOG,
  listMockSymbols,
  getMockSymbol,
  quotePriceForSymbol,
};
