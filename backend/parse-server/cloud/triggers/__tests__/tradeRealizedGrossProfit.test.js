'use strict';

const { resolveTradeRealizedGrossProfit } = require('../tradeRealizedGrossProfit');

describe('resolveTradeRealizedGrossProfit', () => {
  test('full sell: sellTotal - buyTotal', () => {
    const gp = resolveTradeRealizedGrossProfit({
      buyAmount: 1660,
      quantity: 1000,
      buyOrder: { quantity: 1000, totalAmount: 1660 },
      sellOrders: [{ quantity: 1000, totalAmount: 2310 }],
    });
    expect(gp).toBe(650);
  });

  test('partial sell: proportional buy allocation', () => {
    const gp = resolveTradeRealizedGrossProfit({
      buyAmount: 1000,
      quantity: 100,
      buyOrder: { quantity: 100, totalAmount: 1000 },
      sellOrders: [{ quantity: 50, totalAmount: 600 }],
    });
    expect(gp).toBe(100);
  });

  test('returns null without sell legs', () => {
    expect(resolveTradeRealizedGrossProfit({
      buyAmount: 1000,
      quantity: 100,
      buyOrder: { quantity: 100, totalAmount: 1000 },
      sellOrders: [],
    })).toBeNull();
  });
});
