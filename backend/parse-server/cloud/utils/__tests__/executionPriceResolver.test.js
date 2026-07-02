'use strict';

const {
  resolvePairedBuyExecutionPrice,
  resolveOrderExecutionPrice,
  absBpsDiff,
} = require('../executionPriceResolver');

jest.mock('../configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    limits: {
      executionPriceMarketDataMaxAgeSeconds: 300,
    },
  })),
}));

function mockParseWithMarketData({ price = 42.5, timestamp = new Date(), noData = false } = {}) {
  const marketRow = noData
    ? null
    : {
      get(key) {
        if (key === 'price') return price;
        if (key === 'timestamp') return timestamp;
        return undefined;
      },
    };

  global.Parse = {
    Query: jest.fn(() => ({
      equalTo: jest.fn().mockReturnThis(),
      descending: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue(marketRow),
    })),
    Error: class extends Error {
      constructor(code, message) {
        super(message);
        this.code = code;
      }
      static get INVALID_VALUE() { return 400; }
    },
  };
}

describe('executionPriceResolver', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('resolveOrderExecutionPrice maps limit orderType to limit_price', async () => {
    const result = await resolveOrderExecutionPrice({
      symbol: 'ABC123',
      orderType: 'limit',
      limitPrice: 3.25,
    });
    expect(result.executionPrice).toBe(3.25);
    expect(result.priceSource).toBe('limit_price');
  });

  test('limit order uses limitPrice as execution price', async () => {
    const result = await resolvePairedBuyExecutionPrice({
      symbol: 'ABC123',
      orderInstruction: 'limit',
      limitPrice: 2.5,
    });
    expect(result.executionPrice).toBe(2.5);
    expect(result.priceSource).toBe('limit_price');
  });

  test('market order uses fresh server MarketData (intent-only)', async () => {
    mockParseWithMarketData({ price: 100 });

    const result = await resolvePairedBuyExecutionPrice({
      symbol: 'E2E-PAIRED-WKN',
      orderInstruction: 'market',
    });
    expect(result.executionPrice).toBe(100);
    expect(result.priceSource).toBe('server_market_data');
    expect(result.clientSubmittedPrice).toBeNull();
  });

  test('rejects market order when MarketData is missing', async () => {
    mockParseWithMarketData({ noData: true });

    await expect(resolvePairedBuyExecutionPrice({
      symbol: 'WKN1',
      orderInstruction: 'market',
    })).rejects.toThrow(/no market data/i);
  });

  test('rejects stale MarketData', async () => {
    const stale = new Date(Date.now() - 400_000);
    mockParseWithMarketData({ price: 50, timestamp: stale });

    await expect(resolvePairedBuyExecutionPrice({
      symbol: 'WKN1',
      orderInstruction: 'market',
    })).rejects.toThrow(/stale/i);
  });

  test('absBpsDiff within 1%', () => {
    expect(absBpsDiff(100, 100.5)).toBeLessThanOrEqual(100);
    expect(absBpsDiff(100, 102)).toBeGreaterThan(100);
  });
});
