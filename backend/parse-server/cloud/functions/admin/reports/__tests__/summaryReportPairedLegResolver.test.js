'use strict';

const {
  applyPoolMirrorFromTraderReference,
  reconcilePoolMirrorSoldFromTrader,
} = require('../summaryReportPairedLegResolver');

describe('summaryReportPairedLegResolver pool sell sync', () => {
  const traderTrade = {
    tradeId: 'trader-1',
    buyQuantity: 1000,
    soldQuantity: 1000,
    sellVolumeProgress: 1,
    costBasisPerShare: 3.8,
    sellOrders: [
      { quantity: 362, totalAmount: 1375.6, price: 3.8 },
      { quantity: 638, totalAmount: 2424.4, price: 3.8 },
    ],
  };

  const participations598 = [
    {
      investorId: 'e1',
      investmentStatus: 'completed',
      investmentCapital: 1000,
      buySnapshot: { poolPieces: 598, poolCapitalAllocated: 2272.4 },
    },
  ];

  test('reconcile uses Collection-Bill pool pieces (598), not trader 1000', () => {
    const stalePool = {
      tradeId: 'pool-1',
      buyQuantity: 1000,
      soldQuantity: 362,
      sellVolumeProgress: 0.362,
      impliedBuyQuantityFromPool: null,
    };

    const synced = reconcilePoolMirrorSoldFromTrader(stalePool, traderTrade, participations598);
    expect(synced.buyQuantity).toBe(598);
    expect(synced.impliedBuyQuantityFromPool).toBe(598);
    expect(synced.soldQuantity).toBe(598);
    expect(synced.sellVolumeProgress).toBe(1);
  });

  test('applyPoolMirrorFromTraderReference uses impliedBuyQuantityFromPool when set', () => {
    const pool = {
      tradeId: 'pool-1',
      buyQuantity: 1000,
      soldQuantity: 200,
      sellVolumeProgress: 0.2,
      impliedBuyQuantityFromPool: 598,
    };

    const synced = applyPoolMirrorFromTraderReference(pool, {
      ...traderTrade,
      soldQuantity: 500,
      sellVolumeProgress: 0.5,
    });

    expect(synced.buyQuantity).toBe(598);
    expect(synced.soldQuantity).toBe(299);
    expect(synced.sellVolumeProgress).toBeCloseTo(299 / 598, 4);
  });

  test('partial sell: 362 trader of 1000 → floor pool proportion on 598 pieces', () => {
    const pool = {
      tradeId: 'pool-1',
      buyQuantity: 1000,
      soldQuantity: 0,
      sellVolumeProgress: 0,
    };

    const synced = applyPoolMirrorFromTraderReference(pool, {
      ...traderTrade,
      soldQuantity: 362,
      sellVolumeProgress: 0.362,
    }, participations598);

    expect(synced.buyQuantity).toBe(598);
    expect(synced.soldQuantity).toBe(216);
    expect(synced.sellVolumeProgress).toBeCloseTo(216 / 598, 4);
  });

  test('reconcilePoolMirrorSoldFromTrader leaves aligned pool snap unchanged', () => {
    const aligned = {
      tradeId: 'pool-1',
      buyQuantity: 598,
      impliedBuyQuantityFromPool: 598,
      soldQuantity: 598,
      sellVolumeProgress: 1,
    };
    expect(reconcilePoolMirrorSoldFromTrader(aligned, traderTrade, participations598)).toBe(aligned);
  });
});
