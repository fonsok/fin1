'use strict';

const {
  resolvePairedBuyExecutionPrice,
  absBpsDiff,
} = require('../executionPriceResolver');

jest.mock('../configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    limits: {
      executionPriceMaxQuoteAgeSeconds: 30,
      executionPriceMarketDataMaxAgeSeconds: 300,
      executionPriceToleranceBps: 100,
    },
  })),
}));

describe('executionPriceResolver', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('limit order uses limitPrice as execution price', async () => {
    const result = await resolvePairedBuyExecutionPrice({
      symbol: 'ABC123',
      orderInstruction: 'limit',
      limitPrice: 2.5,
      clientPrice: 9.99,
    });
    expect(result.executionPrice).toBe(2.5);
    expect(result.priceSource).toBe('limit_price');
  });

  test('market order validates fresh client quote when no MarketData', async () => {
    const query = {
      equalTo: jest.fn().mockReturnThis(),
      descending: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      first: jest.fn().mockResolvedValue(null),
    };
    global.Parse = {
      Query: jest.fn(() => query),
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_VALUE() { return 400; }
      },
    };

    const now = new Date().toISOString();
    const result = await resolvePairedBuyExecutionPrice({
      symbol: 'E2E-PAIRED-WKN',
      orderInstruction: 'market',
      clientPrice: 100,
      clientQuotedAt: now,
    });
    expect(result.executionPrice).toBe(100);
    expect(result.priceSource).toBe('client_quote_validated');
  });

  test('rejects stale client quote', async () => {
    global.Parse = {
      Query: jest.fn(() => ({
        equalTo: jest.fn().mockReturnThis(),
        descending: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        first: jest.fn().mockResolvedValue(null),
      })),
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_VALUE() { return 400; }
      },
    };

    const stale = new Date(Date.now() - 60_000).toISOString();
    await expect(resolvePairedBuyExecutionPrice({
      symbol: 'WKN1',
      orderInstruction: 'market',
      clientPrice: 1.5,
      clientQuotedAt: stale,
    })).rejects.toThrow(/expired/i);
  });

  test('absBpsDiff within 1%', () => {
    expect(absBpsDiff(100, 100.5)).toBeLessThanOrEqual(100);
    expect(absBpsDiff(100, 102)).toBeGreaterThan(100);
  });
});
