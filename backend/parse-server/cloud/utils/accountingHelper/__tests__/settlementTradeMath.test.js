'use strict';

const {
  computeTradingFees,
  computeTradingFeesWithBreakdown,
  getOrderArrayFromTradeLike,
  getTotalSellAmount,
  getTotalSellQuantity,
  getRepresentativeSellOrder,
} = require('../settlementTradeMath');

function tradeFrom(attrs) {
  return {
    get(k) {
      return attrs[k];
    },
  };
}

describe('settlementTradeMath', () => {
  describe('getOrderArrayFromTradeLike', () => {
    test('prefers sellOrders array over legacy sellOrder', () => {
      const t = tradeFrom({
        sellOrders: [{ id: 'a' }],
        sellOrder: { id: 'legacy' },
      });
      expect(getOrderArrayFromTradeLike(t)).toEqual([{ id: 'a' }]);
    });

    test('falls back to single sellOrder when sellOrders empty', () => {
      const t = tradeFrom({
        sellOrders: [],
        sellOrder: { id: 'only' },
      });
      expect(getOrderArrayFromTradeLike(t)).toEqual([{ id: 'only' }]);
    });

    test('supports plain object without .get', () => {
      expect(getOrderArrayFromTradeLike({
        sellOrders: [{ x: 1 }],
      })).toEqual([{ x: 1 }]);
    });
  });

  describe('getTotalSellAmount / getTotalSellQuantity', () => {
    test('sums all sell orders', () => {
      const t = tradeFrom({
        sellOrders: [
          { totalAmount: 100, quantity: 10 },
          { totalAmount: 50.5, quantity: 5 },
        ],
      });
      expect(getTotalSellAmount(t)).toBe(150.5);
      expect(getTotalSellQuantity(t)).toBe(15);
    });
  });

  describe('getRepresentativeSellOrder', () => {
    test('returns last sell order in array', () => {
      const t = tradeFrom({
        sellOrders: [{ id: 1 }, { id: 2 }, { id: 3 }],
      });
      expect(getRepresentativeSellOrder(t)).toEqual({ id: 3 });
    });
  });

  describe('computeTradingFeesWithBreakdown', () => {
    test('aggregates fees for buy plus each sell (foreign leg each time)', () => {
      const t = tradeFrom({
        buyOrder: { totalAmount: 1000 },
        sellOrders: [{ totalAmount: 2000 }],
      });
      const { totalFees, breakdown } = computeTradingFeesWithBreakdown(t);
      expect(breakdown).toMatchObject({
        orderFee: expect.any(Number),
        exchangeFee: expect.any(Number),
        foreignCosts: expect.any(Number),
      });
      expect(totalFees).toBe(
        Math.round((breakdown.orderFee + breakdown.exchangeFee + breakdown.foreignCosts) * 100) / 100,
      );
      expect(totalFees).toBeGreaterThan(0);
    });

    test('handles missing buyOrder (sells only)', () => {
      const t = tradeFrom({
        sellOrders: [{ totalAmount: 500 }],
      });
      const { totalFees, breakdown } = computeTradingFeesWithBreakdown(t);
      expect(breakdown.orderFee).toBeGreaterThanOrEqual(0);
      expect(totalFees).toBeGreaterThan(0);
    });
  });

  describe('computeTradingFees', () => {
    test('matches totalFees from computeTradingFeesWithBreakdown', () => {
      const t = tradeFrom({
        buyOrder: { totalAmount: 300 },
        sellOrder: { totalAmount: 400 },
      });
      expect(computeTradingFees(t)).toBe(computeTradingFeesWithBreakdown(t).totalFees);
    });
  });
});
