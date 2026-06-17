'use strict';

jest.mock('../../utils/configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    limits: {
      executionPriceMaxQuoteAgeSeconds: 30,
      executionPriceMarketDataMaxAgeSeconds: 300,
      executionPriceToleranceBps: 100,
    },
  })),
}));

jest.mock('../../utils/helpers', () => ({
  generateSequentialNumber: jest.fn(async () => 'ORD-TEST-1'),
}));

jest.mock('../../utils/pairedOrderStatusCoupling', () => ({
  assertPairedOrderStatusCouplingOnSave: jest.fn(async () => {}),
}));

function makeOrder(attrs = {}) {
  const store = new Map(Object.entries(attrs));
  return {
    existed: () => false,
    get(key) { return store.has(key) ? store.get(key) : undefined; },
    set(key, value) { store.set(key, value); },
    has(key) { return store.has(key); },
  };
}

describe('orderTriggerBeforeSave execution price (ADR-019)', () => {
  let beforeSaveHandler;

  beforeAll(() => {
    global.Parse = {
      Cloud: { beforeSave: jest.fn((name, fn) => { beforeSaveHandler = fn; }) },
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_VALUE() { return 400; }
      },
      Query: jest.fn(() => ({
        equalTo: jest.fn().mockReturnThis(),
        descending: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        first: jest.fn().mockResolvedValue(null),
      })),
    };
    jest.isolateModules(() => {
      require('../../triggers/orderTriggerBeforeSave');
    });
  });

  test('new sell order gets server execution price metadata', async () => {
    const now = new Date().toISOString();
    const order = makeOrder({
      traderId: 'trader-1',
      symbol: 'WKN-SELL',
      side: 'sell',
      orderType: 'market',
      quantity: 10,
      price: 99.5,
      clientQuotedAt: now,
    });

    await beforeSaveHandler({ object: order, original: null });

    expect(order.get('executionPriceSource')).toBe('client_quote_validated');
    expect(order.get('price')).toBe(99.5);
    expect(order.get('grossAmount')).toBe(995);
    expect(order.get('clientSubmittedPrice')).toBe(99.5);
  });

  test('sell order with pairExecutionId skips resolver', async () => {
    const order = makeOrder({
      traderId: 'trader-1',
      symbol: 'WKN-SELL',
      side: 'sell',
      orderType: 'market',
      quantity: 5,
      price: 10,
      pairExecutionId: 'pair-123',
      clientQuotedAt: new Date().toISOString(),
    });

    await beforeSaveHandler({ object: order, original: null });

    expect(order.get('executionPriceSource')).toBeUndefined();
    expect(order.get('grossAmount')).toBeUndefined();
  });
});
