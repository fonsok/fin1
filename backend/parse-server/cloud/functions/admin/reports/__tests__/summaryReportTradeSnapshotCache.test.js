'use strict';

const { createTradeLegSnapshotCache } = require('../summaryReportTradeSnapshotCache');
const { buildPairedLegSnapshotsForRow } = require('../summaryReportPairedLegResolver');

function mockTrade(id, data = {}) {
  return {
    id,
    get(key) {
      return data[key];
    },
  };
}

describe('summaryReportTradeSnapshotCache', () => {
  test('getLegSnap builds at most once per tradeId', () => {
    const cache = createTradeLegSnapshotCache({});
    const trade = mockTrade('t1', {
      tradeNumber: 1,
      symbol: 'X',
      status: 'active',
      quantity: 100,
      soldQuantity: 0,
      buyOrder: { quantity: 100, totalAmount: 500, price: 5 },
      sellOrders: [],
    });

    const a = cache.getLegSnap(trade);
    const b = cache.getLegSnap(trade);
    expect(a).toBe(b);
    expect(cache.stats().legSnapBuildCount).toBe(1);
  });

  test('getPoolMirrorSnap dedupes by pool + participations + trader', () => {
    const cache = createTradeLegSnapshotCache({});
    const pool = mockTrade('pool-1', {
      tradeNumber: 2,
      symbol: 'X',
      status: 'active',
      quantity: 1000,
      soldQuantity: 0,
      buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
      sellOrders: [],
    });
    const traderRef = {
      tradeId: 'trader-1',
      buyQuantity: 1000,
      bidPricePerShare: 3.74,
      sellOrders: [],
    };
    const participations = [
      { investorId: 'i1', investmentStatus: 'active', investmentCapital: 1500 },
      { investorId: 'i2', investmentStatus: 'active', investmentCapital: 1500 },
    ];

    const first = cache.getPoolMirrorSnap(pool, participations, traderRef);
    const second = cache.getPoolMirrorSnap(pool, participations, traderRef);
    expect(first).toBe(second);
    expect(cache.stats().poolMirrorBuildCount).toBe(1);
    expect(first.buyQuantity).toBe(797);
  });
});

describe('buildPairedLegSnapshotsForRow', () => {
  test('trader row + pool row share one trader leg snap via cache', () => {
    const cache = createTradeLegSnapshotCache({});
    const tradeById = new Map();
    const participationsByPool = new Map();

    const traderData = {
      tradeNumber: 1,
      symbol: 'GS4GLEF',
      status: 'active',
      quantity: 1000,
      soldQuantity: 0,
      buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
      sellOrders: [],
      traderId: 'trader',
    };
    const poolData = {
      tradeNumber: 2,
      symbol: 'GS4GLEF',
      status: 'active',
      quantity: 1000,
      soldQuantity: 0,
      buyOrder: { quantity: 1000, totalAmount: 3740, price: 3.74 },
      sellOrders: [],
      traderId: 'trader',
    };

    const traderRow = mockTrade('trader-1', traderData);
    const poolRow = mockTrade('pool-1', poolData);
    tradeById.set('trader-1', traderRow);
    tradeById.set('pool-1', poolRow);

    const participations = [
      { investorId: 'i1', investmentStatus: 'active', investmentCapital: 1500 },
      { investorId: 'i2', investmentStatus: 'active', investmentCapital: 1500 },
    ];
    participationsByPool.set('pool-1', participations);

    const traderCtx = {
      legKind: 'trader',
      traderTradeId: 'trader-1',
      mirrorTradeId: 'pool-1',
      poolTradeId: 'pool-1',
      pairExecutionId: 'pair-1',
    };
    const poolCtx = {
      legKind: 'mirror_pool',
      traderTradeId: 'trader-1',
      mirrorTradeId: 'pool-1',
      poolTradeId: 'pool-1',
      pairExecutionId: 'pair-1',
    };

    const traderBuilt = buildPairedLegSnapshotsForRow(
      traderRow,
      traderCtx,
      tradeById,
      participationsByPool,
      cache,
    );
    const poolBuilt = buildPairedLegSnapshotsForRow(
      poolRow,
      poolCtx,
      tradeById,
      participationsByPool,
      cache,
    );

    expect(traderBuilt.traderTrade.tradeId).toBe('trader-1');
    expect(poolBuilt.traderTrade.tradeId).toBe('trader-1');
    expect(traderBuilt.traderTrade).toBe(poolBuilt.traderTrade);
    expect(traderBuilt.poolMirrorTrade.tradeId).toBe('pool-1');
    expect(poolBuilt.poolMirrorTrade.tradeId).toBe('pool-1');
    expect(traderBuilt.poolMirrorTrade).toBe(poolBuilt.poolMirrorTrade);
    expect(cache.stats().legSnapBuildCount).toBe(1);
    expect(cache.stats().poolMirrorBuildCount).toBe(1);
  });
});
