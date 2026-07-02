'use strict';

jest.mock('../../executionPriceResolver', () => ({
  round4: (n) => Math.round(Number(n) * 10000) / 10000,
  fetchLatestMarketDataPrice: jest.fn(),
}));

const { fetchLatestMarketDataPrice } = require('../../executionPriceResolver');
const {
  resolveFeedEntry,
  defaultBasePriceForSymbol,
} = require('../feedEntryResolver');

describe('feedEntryResolver', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('resolveFeedEntry returns catalog entry when known', async () => {
    const entry = await resolveFeedEntry('865985');
    expect(entry.symbol).toBe('865985');
    expect(entry.basePrice).toBe(175);
    expect(entry.label).toBe('Apple');
  });

  test('resolveFeedEntry uses last MarketData price for unknown symbol', async () => {
    fetchLatestMarketDataPrice.mockResolvedValueOnce({ price: 88.5, timestamp: new Date() });
    const entry = await resolveFeedEntry('OPTION-XYZ');
    expect(entry.symbol).toBe('OPTION-XYZ');
    expect(entry.basePrice).toBe(88.5);
    expect(entry.label).toBe('last_market_data');
  });

  test('resolveFeedEntry falls back to deterministic synthetic price', async () => {
    fetchLatestMarketDataPrice.mockResolvedValueOnce(null);
    const entry = await resolveFeedEntry('OPTION-XYZ');
    expect(entry.symbol).toBe('OPTION-XYZ');
    expect(entry.basePrice).toBe(defaultBasePriceForSymbol('OPTION-XYZ'));
    expect(entry.label).toBe('synthetic_default');
  });
});
