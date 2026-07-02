'use strict';

const { handleUpsertMarketDataQuote } = require('../upsertMarketDataQuote');

describe('upsertMarketDataQuote (ADR-019 Phase 8)', () => {
  let savedRows;

  beforeEach(() => {
    savedRows = [];

    global.Parse = {
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
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

  test('rejects unauthenticated callers', async () => {
    await expect(handleUpsertMarketDataQuote({ user: null, params: {} }))
      .rejects.toMatchObject({ message: 'Login required' });
  });

  test('rejects non-trader role', async () => {
    const user = { get: (k) => (k === 'role' ? 'investor' : null) };
    await expect(handleUpsertMarketDataQuote({ user, params: { symbol: 'X', price: 10 } }))
      .rejects.toMatchObject({ message: 'Trader role required' });
  });

  test('persists fresh MarketData row for execution resolver', async () => {
    const user = { get: (k) => (k === 'role' ? 'trader' : null) };
    const result = await handleUpsertMarketDataQuote({
      user,
      params: { symbol: ' E2E-WKN ', price: 42.12345 },
    });

    expect(result).toMatchObject({
      symbol: 'E2E-WKN',
      price: 42.1235,
    });
    expect(result.publishedAt).toBeTruthy();
    expect(savedRows).toHaveLength(1);
    expect(savedRows[0]).toMatchObject({
      symbol: 'E2E-WKN',
      price: 42.1235,
      exchange: 'FIN1',
    });
    expect(savedRows[0].timestamp).toBeInstanceOf(Date);
  });
});
