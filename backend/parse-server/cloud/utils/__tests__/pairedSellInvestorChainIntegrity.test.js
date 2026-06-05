'use strict';

const {
  mirrorTradeHasSyncedExitEconomics,
  traderTradeHasSellActivity,
} = require('../pairedSellInvestorChainIntegrity');

function makeTrade(attrs) {
  return {
    id: attrs.id || 'trade-1',
    get(k) {
      return attrs[k];
    },
  };
}

describe('pairedSellInvestorChainIntegrity helpers', () => {
  test('mirrorTradeHasSyncedExitEconomics true when sellOrders present', () => {
    const trade = makeTrade({ sellOrders: [{ quantity: 10, price: 3 }] });
    expect(mirrorTradeHasSyncedExitEconomics(trade)).toBe(true);
  });

  test('mirrorTradeHasSyncedExitEconomics false for buy-only mirror', () => {
    const trade = makeTrade({ status: 'active', quantity: 100 });
    expect(mirrorTradeHasSyncedExitEconomics(trade)).toBe(false);
  });

  test('traderTradeHasSellActivity when soldQuantity > 0', () => {
    const trade = makeTrade({ soldQuantity: 500, status: 'partial' });
    expect(traderTradeHasSellActivity(trade)).toBe(true);
  });

  test('traderTradeHasSellActivity false for open buy-only', () => {
    const trade = makeTrade({ soldQuantity: 0, status: 'active', sellOrders: [] });
    expect(traderTradeHasSellActivity(trade)).toBe(false);
  });
});
