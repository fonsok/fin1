'use strict';

const {
  sumPoolPiecesFromParticipations,
  resolvePoolBuyQuantity,
  derivePoolSellState,
  reconcilePoolMirrorSnapshot,
  applyPoolMirrorEconomicsToSnapshot,
} = require('../resolvePoolMirrorState');

describe('resolvePoolMirrorState SSOT', () => {
  const participations598 = [
    {
      investorId: 'e1',
      investmentStatus: 'completed',
      investmentCapital: 1000,
      buySnapshot: { poolPieces: 598, poolCapitalAllocated: 2272.4 },
    },
  ];

  const traderTrade = {
    buyQuantity: 1000,
    soldQuantity: 1000,
    sellVolumeProgress: 1,
    costBasisPerShare: 3.8,
  };

  test('sumPoolPiecesFromParticipations uses buySnapshot regardless of status', () => {
    expect(sumPoolPiecesFromParticipations(participations598)).toBe(598);
  });

  test('resolvePoolBuyQuantity rejects mirror placeholder equal to trader buy', () => {
    expect(resolvePoolBuyQuantity({
      participations: [],
      poolMirrorTrade: { buyQuantity: 1000 },
      traderTrade: { buyQuantity: 1000 },
    })).toBe(0);
  });

  test('reconcilePoolMirrorSnapshot patches stale pool row from participations', () => {
    const stalePool = {
      buyQuantity: 1000,
      soldQuantity: 362,
      sellVolumeProgress: 0.362,
    };
    const synced = reconcilePoolMirrorSnapshot(stalePool, traderTrade, participations598);
    expect(synced.buyQuantity).toBe(598);
    expect(synced.impliedBuyQuantityFromPool).toBe(598);
    expect(synced.soldQuantity).toBe(598);
    expect(synced.sellVolumeProgress).toBe(1);
  });

  test('derivePoolSellState maps partial trader sell to pool pieces', () => {
    const partialTrader = { ...traderTrade, soldQuantity: 362, sellVolumeProgress: 0.362 };
    const state = derivePoolSellState(598, partialTrader);
    expect(state.soldQuantity).toBe(216);
    expect(state.sellVolumeProgress).toBeCloseTo(216 / 598, 4);
  });

  test('applyPoolMirrorEconomicsToSnapshot always applies economics', () => {
    const pool = { buyQuantity: 1000, soldQuantity: 0, sellVolumeProgress: 0 };
    const synced = applyPoolMirrorEconomicsToSnapshot(pool, traderTrade, participations598);
    expect(synced.buyQuantity).toBe(598);
    expect(synced.soldQuantity).toBe(598);
  });

  test('reconcilePoolMirrorSnapshot leaves aligned snapshot unchanged', () => {
    const aligned = {
      buyQuantity: 598,
      impliedBuyQuantityFromPool: 598,
      soldQuantity: 598,
      sellVolumeProgress: 1,
    };
    expect(reconcilePoolMirrorSnapshot(aligned, traderTrade, participations598)).toBe(aligned);
  });
});
