'use strict';

const {
  listMockSymbols,
  getMockSymbol,
  quotePriceForSymbol,
} = require('../mockSymbolCatalog');

describe('mockSymbolCatalog', () => {
  test('includes iOS stock WKNs', () => {
    const symbols = listMockSymbols().map((entry) => entry.symbol);
    expect(symbols).toEqual(expect.arrayContaining(['865985', '519000', '881160']));
  });

  test('quotePriceForSymbol jitters within ±1% of base', () => {
    const entry = getMockSymbol('865985');
    const price = quotePriceForSymbol(entry, new Date('2026-07-01T12:00:00.000Z'));
    expect(price).toBeGreaterThan(entry.basePrice * 0.99);
    expect(price).toBeLessThan(entry.basePrice * 1.01);
  });
});
