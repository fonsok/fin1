'use strict';

global.Parse = {
  Error: class ParseError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  },
};
Parse.Error.INVALID_VALUE = 142;

jest.mock('../loadConfig', () => ({
  loadConfig: jest.fn(async () => ({
    financial: { maxTraderPartialSells: 2 },
  })),
}));

const {
  countTraderPartialSellEvents,
  assertTraderPartialSellWithinLimit,
  getMaxTraderPartialSells,
} = require('../traderPartialSellLimits');

function mockTrade(data) {
  return {
    get(key) {
      return data[key];
    },
  };
}

describe('traderPartialSellLimits', () => {
  test('getMaxTraderPartialSells clamps 0–3', async () => {
    expect(await getMaxTraderPartialSells()).toBe(2);
  });

  test('countTraderPartialSellEvents: open partials vs completion', () => {
    const partial = mockTrade({
      quantity: 100,
      buyOrder: { quantity: 100 },
      sellOrders: [{ quantity: 30 }, { quantity: 20 }],
      soldQuantity: 50,
    });
    expect(countTraderPartialSellEvents(partial)).toBe(2);

    const done = mockTrade({
      quantity: 100,
      buyOrder: { quantity: 100 },
      sellOrders: [{ quantity: 60 }, { quantity: 40 }],
      soldQuantity: 100,
    });
    expect(countTraderPartialSellEvents(done)).toBe(1);
  });

  test('max=0 rejects partial sell', async () => {
    const prev = mockTrade({
      quantity: 100,
      buyOrder: { quantity: 100 },
      sellOrders: [],
      soldQuantity: 0,
    });
    const next = mockTrade({
      quantity: 100,
      buyOrder: { quantity: 100 },
      sellOrders: [{ quantity: 40 }],
      soldQuantity: 40,
    });
    await expect(assertTraderPartialSellWithinLimit(next, prev, 0)).rejects.toThrow(/deaktiviert/i);
  });

  test('max=2 rejects third partial', async () => {
    const prev = mockTrade({
      quantity: 100,
      buyOrder: { quantity: 100 },
      sellOrders: [{ quantity: 20 }, { quantity: 20 }],
      soldQuantity: 40,
    });
    const next = mockTrade({
      quantity: 100,
      buyOrder: { quantity: 100 },
      sellOrders: [{ quantity: 20 }, { quantity: 20 }, { quantity: 10 }],
      soldQuantity: 50,
    });
    await expect(assertTraderPartialSellWithinLimit(next, prev, 2)).rejects.toThrow(/vollständig|Maximal 2/i);
  });

  test('max=3 last allowed partial must sell full remaining', async () => {
    const prev = mockTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000 },
      sellOrders: [{ quantity: 200 }, { quantity: 500 }],
      soldQuantity: 700,
    });
    const nextPartial = mockTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000 },
      sellOrders: [{ quantity: 200 }, { quantity: 500 }, { quantity: 100 }],
      soldQuantity: 800,
    });
    await expect(assertTraderPartialSellWithinLimit(nextPartial, prev, 3)).rejects.toThrow(/Restposition/i);

    const nextFull = mockTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000 },
      sellOrders: [{ quantity: 200 }, { quantity: 500 }, { quantity: 300 }],
      soldQuantity: 1000,
    });
    await expect(assertTraderPartialSellWithinLimit(nextFull, prev, 3)).resolves.toBeUndefined();
  });

  test('max=3 limit exhausted allows full remaining exit (recovery)', async () => {
    const prev = mockTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000 },
      sellOrders: [{ quantity: 200 }, { quantity: 500 }, { quantity: 100 }],
      soldQuantity: 800,
    });
    const nextFullExit = mockTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000 },
      sellOrders: [{ quantity: 200 }, { quantity: 500 }, { quantity: 100 }, { quantity: 200 }],
      soldQuantity: 1000,
    });
    await expect(assertTraderPartialSellWithinLimit(nextFullExit, prev, 3)).resolves.toBeUndefined();

    const nextPartialExit = mockTrade({
      quantity: 1000,
      buyOrder: { quantity: 1000 },
      sellOrders: [{ quantity: 200 }, { quantity: 500 }, { quantity: 100 }, { quantity: 50 }],
      soldQuantity: 850,
    });
    await expect(assertTraderPartialSellWithinLimit(nextPartialExit, prev, 3)).rejects.toThrow(/vollständig/i);
  });
});
