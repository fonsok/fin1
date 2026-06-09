'use strict';

const {
  buildPoolBuySnapshot,
  buildPoolBuySnapshotsProRata,
} = require('../poolBuySnapshot');

describe('buildPoolBuySnapshot pro-rata', () => {
  const makeTrade = (overrides = {}) => ({
    get(key) {
      const data = {
        buyPrice: 1.66,
        quantity: 1000,
        buyAmount: 1660,
        ...overrides,
      };
      return data[key];
    },
  });

  const zeroFees = {
    orderFeeRate: 0,
    exchangeFeeRate: 0,
    foreignCosts: 0,
    orderFeeMin: 0,
    exchangeFeeMin: 0,
  };

  test('single investor: trade-level Stück × Einstand', () => {
    const buyOrder = { price: 3.78, quantity: 1000, totalAmount: 3780 };
    const trade = makeTrade({ buyPrice: 3.78, quantity: 1000, buyAmount: 3780 });
    const snap = buildPoolBuySnapshot(trade, 3000, buyOrder, { feeConfig: zeroFees });

    expect(snap).not.toBeNull();
    expect(snap.costBasisPerShare).toBe(3.78);
    expect(snap.poolPieces).toBe(793);
    expect(snap.poolCapitalAllocated).toBe(2997.54);
    expect(snap.residualAmount).toBe(2.46);
    expect(snap.investmentAmount).toBe(3000);
  });

  test('two investors: residual proportional zur Einlage', () => {
    const buyOrder = { price: 10, quantity: 400, totalAmount: 4000 };
    const trade = makeTrade({ buyPrice: 10, quantity: 400, buyAmount: 4000 });
    const snaps = buildPoolBuySnapshotsProRata(trade, [1000, 3000], buyOrder, { feeConfig: zeroFees });

    expect(snaps).toHaveLength(2);
    expect(snaps[0].investmentAmount).toBe(1000);
    expect(snaps[1].investmentAmount).toBe(3000);
    expect(snaps[0].poolPieces).toBe(100);
    expect(snaps[1].poolPieces).toBe(300);
    expect(snaps[0].poolCapitalAllocated).toBe(1000);
    expect(snaps[1].poolCapitalAllocated).toBe(3000);
    expect(snaps[0].residualAmount).toBe(0);
    expect(snaps[1].residualAmount).toBe(0);
  });

  test('two investors with pool residual split 25/75', () => {
    const buyOrder = { price: 9.992, quantity: 1000, totalAmount: 9992 };
    const trade = makeTrade({ buyPrice: 9.992, quantity: 1000, buyAmount: 9992 });
    const snaps = buildPoolBuySnapshotsProRata(trade, [1000, 3000], buyOrder, { feeConfig: zeroFees });

    expect(snaps[0].residualAmount).toBe(1);
    expect(snaps[1].residualAmount).toBe(3);
    expect(snaps[0].poolCapitalAllocated + snaps[0].residualAmount).toBe(1000);
    expect(snaps[1].poolCapitalAllocated + snaps[1].residualAmount).toBe(3000);
  });

  test('returns null when investmentCapital is 0', () => {
    const snap = buildPoolBuySnapshot(makeTrade(), 0, { price: 1.66 });
    expect(snap).toBeNull();
  });
});
