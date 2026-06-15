'use strict';

const {
  computeTradingFees,
  computeTradingFeesWithBreakdown,
  getOrderArrayFromTradeLike,
  getSellOrdersAddedSince,
  getTotalSellAmount,
  getTotalSellNetCashAmount,
  getTotalSellQuantity,
  getRepresentativeSellOrder,
  resolveSellOrderGrossAmount,
  resolveSellOrderNetCashAmount,
  resolveSellOrderKey,
  findSellOrderForBelegLeg,
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

  describe('resolveSellOrderKey', () => {
    test('prefers id then objectId then orderId', () => {
      expect(resolveSellOrderKey({ id: 'a', objectId: 'b' })).toBe('a');
      expect(resolveSellOrderKey({ objectId: 'b', orderId: 'c' })).toBe('b');
      expect(resolveSellOrderKey(null)).toBe('');
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

  describe('resolveSellOrderNetCashAmount', () => {
    test('subtracts order fees from gross totalAmount', () => {
      const order = { totalAmount: 1000 };
      const net = resolveSellOrderNetCashAmount(order, {});
      expect(net).toBeLessThan(1000);
      expect(net).toBeGreaterThan(990);
    });
  });

  describe('getSellOrdersAddedSince', () => {
    test('returns only sell orders not present on previous trade', () => {
      const previous = tradeFrom({
        sellOrders: [{ id: 'sell-1', totalAmount: 500 }],
      });
      const current = tradeFrom({
        sellOrders: [
          { id: 'sell-1', totalAmount: 500 },
          { id: 'sell-2', totalAmount: 1000 },
        ],
      });
      expect(getSellOrdersAddedSince(previous, current)).toEqual([
        { id: 'sell-2', totalAmount: 1000 },
      ]);
    });
  });

  describe('getTotalSellNetCashAmount', () => {
    test('sums net cash per sell order', () => {
      const t = tradeFrom({
        sellOrders: [{ totalAmount: 1000 }, { totalAmount: 500 }],
      });
      const gross = getTotalSellAmount(t);
      const net = getTotalSellNetCashAmount(t, {});
      expect(net).toBeLessThan(gross);
      expect(resolveSellOrderGrossAmount({ totalAmount: 1000 })).toBe(1000);
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

  describe('findSellOrderForBelegLeg', () => {
    const trade = tradeFrom({
      sellOrders: [
        { id: 'sell-1', quantity: 400, totalAmount: 1600 },
        { id: 'sell-2', quantity: 800, totalAmount: 2400 },
      ],
    });

    test('uses sellOrderId when amount matches', () => {
      expect(findSellOrderForBelegLeg(trade, {
        sellOrderId: 'sell-1',
        grossAmount: 1600,
        quantity: 400,
      })).toMatchObject({ id: 'sell-1' });
    });

    test('ignores stale sellOrderId when gross amount belongs to another leg', () => {
      expect(findSellOrderForBelegLeg(trade, {
        sellOrderId: 'sell-1',
        grossAmount: 2400,
        quantity: 400,
      })).toMatchObject({ id: 'sell-2', quantity: 800 });
    });
  });
});
