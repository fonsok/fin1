'use strict';

const {
  resolveTradeSellPrice,
  resolveSettlementLegPrices,
} = require('../shared');

function mockTrade(data) {
  return {
    id: data.id || 'trade-1',
    get(key) {
      return data[key];
    },
  };
}

describe('resolveTradeSellPrice — multi partial-sell VWAP', () => {
  const multiSellOrders = [
    { quantity: 100, price: 1.8761231280407917, totalAmount: 187.61231280407918 },
    { quantity: 500, price: 1.8436648822190749, totalAmount: 921.8324411095374 },
    { quantity: 400, price: 5, totalAmount: 2000 },
  ];

  test('completed trade with 3 sells uses volume-weighted average, not first leg', () => {
    const trade = mockTrade({
      status: 'completed',
      sellOrders: multiSellOrders,
      quantity: 1000,
    });
    expect(resolveTradeSellPrice(trade)).toBe(3.11);
  });

  test('partial trade with multiple sells keeps first-leg price (per-leg hooks)', () => {
    const trade = mockTrade({
      status: 'partial',
      sellOrders: multiSellOrders.slice(0, 2),
      quantity: 1000,
    });
    expect(resolveTradeSellPrice(trade)).toBe(1.8761231280407917);
  });

  test('resolveSettlementLegPrices uses pool mirror VWAP when completed', () => {
    const pool = mockTrade({
      id: 'pool-1',
      status: 'completed',
      sellOrders: [
        { quantity: 160.4, totalAmount: 300.93 },
        { quantity: 802, totalAmount: 1478.62 },
        { quantity: 641.6, totalAmount: 3208 },
      ],
      buyOrder: { price: 1.86 },
      quantity: 1604,
    });
    const trader = mockTrade({
      id: 'trader-1',
      status: 'completed',
      sellOrders: multiSellOrders,
      buyOrder: { price: 1.86 },
      quantity: 1000,
    });
    const { tradeSellPrice } = resolveSettlementLegPrices(pool, trader);
    expect(tradeSellPrice).toBe(3.11);
  });
});
