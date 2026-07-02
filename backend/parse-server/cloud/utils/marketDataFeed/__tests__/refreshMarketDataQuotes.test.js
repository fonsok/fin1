'use strict';

jest.mock('../../configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    display: {
      marketDataFeedEnabled: true,
      marketDataFeedIntervalSeconds: 60,
    },
  })),
}));

const { refreshMarketDataQuotes, isMarketDataFeedEnabled } = require('../refreshMarketDataQuotes');

describe('refreshMarketDataQuotes', () => {
  let savedRows;

  beforeEach(() => {
    jest.clearAllMocks();
    savedRows = [];
    delete process.env.MARKET_DATA_FEED_ENABLED;

    global.Parse = {
      Query: class MockQuery {
        constructor(className) {
          this.className = className;
        }

        equalTo() {
          return this;
        }

        descending() {
          return this;
        }

        greaterThan() {
          return this;
        }

        exists() {
          return this;
        }

        limit() {
          return this;
        }

        async first() {
          return null;
        }

        async find() {
          return [];
        }
      },
      Object: class MarketData {
        constructor(className) {
          this.className = className;
          this.store = new Map();
        }

        set(key, value) {
          this.store.set(key, value);
        }

        async save(_session, opts) {
          if (!opts?.useMasterKey) throw new Error('master key required');
          savedRows.push(Object.fromEntries(this.store));
        }
      },
    };
  });

  test('is disabled when env MARKET_DATA_FEED_ENABLED=0', async () => {
    process.env.MARKET_DATA_FEED_ENABLED = '0';
    await expect(isMarketDataFeedEnabled()).resolves.toBe(false);
  });

  test('refreshes catalog symbols into MarketData', async () => {
    const result = await refreshMarketDataQuotes({ symbols: ['865985', '519000'] });
    expect(result.enabled).toBe(true);
    expect(result.refreshed).toBe(2);
    expect(savedRows).toHaveLength(2);
    expect(savedRows[0].symbol).toBe('865985');
    expect(savedRows[0].price).toBeGreaterThan(0);
    expect(savedRows[0].timestamp).toBeInstanceOf(Date);
  });

  test('refreshes unknown symbol via synthetic feed entry', async () => {
    const result = await refreshMarketDataQuotes({ symbols: ['EXOTIC-OPTION-WKN'] });
    expect(result.enabled).toBe(true);
    expect(result.refreshed).toBe(1);
    expect(savedRows).toHaveLength(1);
    expect(savedRows[0].symbol).toBe('EXOTIC-OPTION-WKN');
    expect(savedRows[0].price).toBeGreaterThan(0);
  });
});
