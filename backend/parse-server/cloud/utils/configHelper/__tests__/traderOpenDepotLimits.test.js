'use strict';

const { tradeHasOpenDepotPosition } = require('../traderOpenDepotLimits');

describe('tradeHasOpenDepotPosition', () => {
  test('returns true when remaining quantity > 0', () => {
    const trade = {
      get(key) {
        if (key === 'buyOrder') return { quantity: 100 };
        if (key === 'quantity') return 100;
        if (key === 'soldQuantity') return 40;
        return undefined;
      },
    };
    expect(tradeHasOpenDepotPosition(trade)).toBe(true);
  });

  test('returns false when fully sold', () => {
    const trade = {
      get(key) {
        if (key === 'buyOrder') return { quantity: 100 };
        if (key === 'quantity') return 100;
        if (key === 'soldQuantity') return 100;
        return undefined;
      },
    };
    expect(tradeHasOpenDepotPosition(trade)).toBe(false);
  });
});
