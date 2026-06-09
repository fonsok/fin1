'use strict';

/** @global {typeof import('parse/node')} Parse */
global.Parse = global.Parse || {
  Query: jest.fn(),
};

const { syncMirrorTradeBuyFromParticipationSnapshots } = require('../syncMirrorTradeBuyFromSnapshots');

describe('syncMirrorTradeBuyFromParticipationSnapshots', () => {
  const originalQuery = Parse.Query;

  afterEach(() => {
    Parse.Query = originalQuery;
  });

  test('aligns mirror trade quantity and buyAmount from buySnapshot sum', async () => {
    const saved = { calls: 0 };
    const trade = {
      id: 'mirror-1',
      get(key) {
        const data = {
          quantity: 1000,
          buyAmount: 1660,
          buyOrder: { price: 1.66, quantity: 1000, totalAmount: 1660 },
        };
        return data[key];
      },
      set(key, val) {
        this[key] = val;
      },
      save: jest.fn(async () => {
        saved.calls += 1;
        return trade;
      }),
    };

    Parse.Query = jest.fn().mockImplementation(() => ({
      equalTo: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      find: jest.fn().mockResolvedValue([
        {
          get: (key) => (key === 'buySnapshot'
            ? { poolPieces: 598, poolCapitalAllocated: 999.44 }
            : undefined),
        },
      ]),
    }));

    const result = await syncMirrorTradeBuyFromParticipationSnapshots(trade);
    expect(result.synced).toBe(true);
    expect(result.poolPieces).toBe(598);
    expect(trade.quantity).toBe(598);
    expect(trade.buyAmount).toBe(999.44);
    expect(trade.buyOrder.quantity).toBe(598);
    expect(trade.save).toHaveBeenCalledTimes(1);
  });

  test('syncs linked Order row when buyOrderId is set', async () => {
    const orderSave = jest.fn().mockResolvedValue({});
    const trade = {
      id: 'mirror-1',
      get(key) {
        const data = {
          quantity: 1000,
          buyAmount: 1660,
          buyOrderId: 'ord-mirror',
          buyOrder: { price: 1.66, quantity: 1000, totalAmount: 1660 },
        };
        return data[key];
      },
      set(key, val) {
        this[key] = val;
      },
      save: jest.fn(async () => trade),
    };

    Parse.Query = jest.fn().mockImplementation((className) => {
      if (className === 'Order') {
        return {
          get: jest.fn().mockResolvedValue({
            id: 'ord-mirror',
            get: (key) => ({ quantity: 1000, executedQuantity: 1000, grossAmount: 1660, totalAmount: 1660 }[key]),
            set: jest.fn(function set(k, v) { this[k] = v; }),
            save: orderSave,
          }),
        };
      }
      return {
        equalTo: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        find: jest.fn().mockResolvedValue([
          {
            get: (key) => (key === 'buySnapshot'
              ? { poolPieces: 598, poolCapitalAllocated: 999.44 }
              : undefined),
          },
        ]),
      };
    });

    const result = await syncMirrorTradeBuyFromParticipationSnapshots(trade);
    expect(result.synced).toBe(true);
    expect(result.orderSync.synced).toBe(true);
    expect(orderSave).toHaveBeenCalledTimes(1);
  });
});
