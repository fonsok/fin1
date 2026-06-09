'use strict';

const {
  toPersistedLegEconomics,
  isPersistedLegEconomicsCurrent,
  legEconomicsFromPersisted,
} = require('../legEconomicsPersistShared');
const { tradeEconomicsSnapshot } = require('../tradeLegEconomics');

function mockTrade(fields = {}) {
  const data = { sellOrders: [], buyOrder: {}, ...fields };
  return {
    id: data.id || 'trade-1',
    get(key) {
      return data[key];
    },
  };
}

describe('persistTradeLegEconomics', () => {
  test('toPersistedLegEconomics freezes returnPercentage on Einstand basis', () => {
    const persisted = toPersistedLegEconomics({
      tradeId: 't1',
      buyQuantity: 100,
      soldQuantity: 0,
      totalBuyCost: 3761.7,
      buyAmount: 3761.7,
      profit: -3761.7,
    });
    expect(persisted.snapshotVersion).toBe(1);
    expect(persisted.returnPercentage).toBe(-100);
    expect(persisted.soldQuantityAtSnapshot).toBe(0);
  });

  test('tradeEconomicsSnapshot prefers persisted snapshot when sold quantity matches', () => {
    const trade = mockTrade({
      id: 'trade-persisted',
      quantity: 1000,
      buyAmount: 3740,
      buyPrice: 3.74,
      buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
      soldQuantity: 0,
      status: 'active',
      legEconomicsSnapshot: toPersistedLegEconomics({
        tradeId: 'trade-persisted',
        buyQuantity: 1000,
        soldQuantity: 0,
        totalBuyCost: 3761.7,
        buyAmount: 3761.7,
        profit: -3761.7,
        costBasisPerShare: 3.7617,
        bidPricePerShare: 3.74,
      }),
    });

    const snap = tradeEconomicsSnapshot(trade, null, { feeConfig: {}, preferPersisted: true });
    expect(snap.totalBuyCost).toBe(3761.7);
    expect(snap.profit).toBe(-3761.7);
    expect(snap.costBasisPerShare).toBe(3.7617);
  });

  test('tradeEconomicsSnapshot recomputes when persisted sold quantity is stale', () => {
    const trade = mockTrade({
      id: 'trade-stale',
      quantity: 1000,
      buyAmount: 3740,
      buyPrice: 3.74,
      buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
      soldQuantity: 200,
      sellAmount: 748,
      sellOrders: [{ quantity: 200, totalAmount: 748, price: 3.74 }],
      status: 'partial',
      legEconomicsSnapshot: toPersistedLegEconomics({
        tradeId: 'trade-stale',
        buyQuantity: 1000,
        soldQuantity: 0,
        totalBuyCost: 3761.7,
        buyAmount: 3761.7,
        profit: -3761.7,
      }),
    });

    expect(isPersistedLegEconomicsCurrent(trade.get('legEconomicsSnapshot'), trade)).toBe(false);
    const snap = tradeEconomicsSnapshot(trade, null, { feeConfig: {} });
    expect(snap.soldQuantity).toBe(200);
    expect(snap.profit).not.toBe(-3761.7);
  });

  test('legEconomicsFromPersisted merges live status from trade', () => {
    const persisted = toPersistedLegEconomics({
      tradeId: 't2',
      buyQuantity: 10,
      soldQuantity: 10,
      totalBuyCost: 100,
      profit: 5,
    });
    const trade = mockTrade({ id: 't2', status: 'completed', soldQuantity: 10 });
    const snap = legEconomicsFromPersisted(persisted, trade);
    expect(snap.status).toBe('completed');
  });
});
