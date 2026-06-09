'use strict';

const { aggregatePoolInvestmentEconomics } = require('../aggregatePool');

describe('aggregatePoolInvestmentEconomics completed buySnapshot', () => {
  test('uses buySnapshot SSOT when investments are completed (not only active)', () => {
    const participations = [
      {
        investorId: 'e1',
        investmentStatus: 'completed',
        investmentCapital: 1000,
        buySnapshot: {
          poolPieces: 598,
          poolCapitalAllocated: 2272.4,
          investmentAmount: 1000,
          residualAmount: 0.2,
        },
      },
    ];
    const traderRef = {
      buyQuantity: 1000,
      soldQuantity: 1000,
      sellOrders: [{ quantity: 1000, totalAmount: 3800, price: 3.8 }],
    };

    const econ = aggregatePoolInvestmentEconomics(participations, 3.8, traderRef, {
      feeConfig: {},
      sellPrice: 3.8,
      costBasisPerShare: 3.8,
    });

    expect(econ.impliedBuyQuantityFromPool).toBe(598);
    expect(econ.poolSoldQuantityDerived).toBe(598);
    expect(econ.poolSellVolumeProgress).toBe(1);
    expect(econ.poolInvestorCount).toBe(1);
  });
});
