'use strict';

jest.mock('../../utils/configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    limits: {
      executionPriceMarketDataMaxAgeSeconds: 300,
    },
  })),
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

describe('orderTriggerBeforeSave execution price (ADR-019, intent-only)', () => {
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
        first: jest.fn().mockResolvedValue({
          get(key) {
            if (key === 'price') return 99.5;
            if (key === 'timestamp') return new Date();
            return undefined;
          },
        }),
      })),
    };
    jest.isolateModules(() => {
      jest.doMock('../../utils/helpers', () => ({
        generateSequentialNumber: jest.fn(async () => 'ORD-TEST-1'),
      }));
      require('../../triggers/orderTriggerBeforeSave');
    });
  });

  test('new sell market order gets server MarketData execution price', async () => {
    const order = makeOrder({
      traderId: 'trader-1',
      symbol: 'WKN-SELL',
      side: 'sell',
      orderType: 'market',
      quantity: 10,
      price: 1,
    });

    await beforeSaveHandler({ object: order, original: null });

    expect(order.get('executionPriceSource')).toBe('server_market_data');
    expect(order.get('price')).toBe(99.5);
    expect(order.get('grossAmount')).toBe(995);
    expect(order.get('clientSubmittedPrice')).toBeUndefined();
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
    });

    await beforeSaveHandler({ object: order, original: null });

    expect(order.get('executionPriceSource')).toBeUndefined();
    expect(order.get('grossAmount')).toBeUndefined();
  });
});
