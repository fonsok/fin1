'use strict';

const { normalizeTradeForClient } = require('../tradeClientPresentation');

describe('normalizeTradeForClient realized profit', () => {
  test('overrides stale calculatedProfit from cumulative sellOrders', () => {
    const trade = {
      id: 't1',
      get(key) {
        const data = {
          traderId: 'trader-1',
          tradeNumber: 1,
          symbol: 'TEST',
          status: 'completed',
          quantity: 1000,
          buyAmount: 1660,
          buyPrice: 1.66,
          calculatedProfit: -660,
          grossProfit: -660,
          buyOrder: { quantity: 1000, totalAmount: 1660, price: 1.66 },
          sellOrders: [
            { quantity: 500, totalAmount: 1000, price: 2 },
            { quantity: 200, totalAmount: 600, price: 3 },
            { quantity: 300, totalAmount: 496.73, price: 1.66 },
          ],
          createdAt: new Date('2026-06-06'),
          updatedAt: new Date('2026-06-07'),
        };
        return data[key];
      },
      toJSON() {
        return {
          objectId: 't1',
          traderId: 'trader-1',
          tradeNumber: 1,
          symbol: 'TEST',
          status: 'completed',
          calculatedProfit: -660,
          grossProfit: -660,
          buyAmount: 1660,
          buyOrder: this.get('buyOrder'),
          sellOrders: this.get('sellOrders'),
          createdAt: this.get('createdAt'),
          updatedAt: this.get('updatedAt'),
        };
      },
    };

    const normalized = normalizeTradeForClient(trade);
    expect(normalized.calculatedProfit).toBeCloseTo(436.73, 1);
    expect(normalized.grossProfit).toBeCloseTo(436.73, 1);
    expect(normalized.calculatedProfit).toBeGreaterThan(0);
  });
});
