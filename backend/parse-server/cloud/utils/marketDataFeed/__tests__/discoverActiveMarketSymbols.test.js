'use strict';

const { discoverActiveMarketSymbols } = require('../discoverActiveMarketSymbols');

describe('discoverActiveMarketSymbols', () => {
  beforeEach(() => {
    global.Parse = {
      Query: class MockQuery {
        constructor(className) {
          this.className = className;
          this.rows = [];
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

        async find() {
          return this.rows;
        }
      },
    };
  });

  test('returns distinct symbols from Trade and Order', async () => {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.rows = [
      { get: (key) => (key === 'symbol' ? '865985' : null) },
      { get: (key) => (key === 'symbol' ? 'OPTION-A' : null) },
    ];
    const orderQuery = new Parse.Query('Order');
    orderQuery.rows = [
      { get: (key) => (key === 'symbol' ? '865985' : null) },
      { get: (key) => (key === 'symbol' ? 'OPTION-B' : null) },
    ];

    const originalQuery = Parse.Query;
    Parse.Query = jest.fn((className) => {
      if (className === 'Trade') return tradeQuery;
      if (className === 'Order') return orderQuery;
      return new originalQuery(className);
    });

    const symbols = await discoverActiveMarketSymbols({ limit: 10 });
    expect(symbols).toEqual(['865985', 'OPTION-A', 'OPTION-B']);
  });
});
