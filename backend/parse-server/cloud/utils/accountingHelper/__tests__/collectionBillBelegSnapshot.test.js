'use strict';

const {
  buildCollectionBillBelegSnapshot,
  TOLERANCE,
} = require('../collectionBillBelegSnapshot');

describe('buildCollectionBillBelegSnapshot — GoB invariants', () => {
  test('eweber-style: nominal = totalBuyCost + residual; transfer = netSell − commission', () => {
    const buyLeg = {
      quantity: 493,
      amount: 1488.86,
      price: 3.02,
      fees: { totalFees: 10.44, orderFee: 7.44, exchangeFee: 0.5, foreignCosts: 2.5 },
      residualAmount: 0.71,
    };
    const sellLeg = {
      quantity: 493,
      amount: 2465,
      price: 5,
      fees: { totalFees: 15.33, orderFee: 12.33, exchangeFee: 0.5, foreignCosts: 2.5 },
    };
    const { metadata, booking } = buildCollectionBillBelegSnapshot({
      investmentCapital: 1500,
      ownershipPercentage: 100,
      commissionRate: 0.1,
      buyLeg,
      sellLeg,
      grossProfit: 950.37,
      commission: 95.04,
      netProfit: 855.33,
      returnPercentage: 57.02,
    });

    expect(metadata.residualAmount).toBe(0.71);
    expect(metadata.totalBuyCost).toBe(1499.29);
    expect(metadata.investmentNominal).toBe(1500);
    expect(metadata.transferAmount).toBe(2354.63);
    expect(booking.poolTradingAmount).toBe(1499.29);
    expect(Math.abs(metadata.netSellAmount - 2449.67)).toBeLessThanOrEqual(TOLERANCE);
  });

  test('fail-closed when legs missing', () => {
    expect(() => buildCollectionBillBelegSnapshot({
      investmentCapital: 1000,
      ownershipPercentage: 100,
      commissionRate: 0.1,
      buyLeg: null,
      sellLeg: { amount: 100, fees: { totalFees: 0 } },
    })).toThrow(/requires buyLeg and sellLeg/);
  });
});
