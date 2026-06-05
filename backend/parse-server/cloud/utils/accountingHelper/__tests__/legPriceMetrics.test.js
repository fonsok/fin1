'use strict';

const { computeInvestorBuyLeg } = require('../legs');
const {
  costBasisPerShareFromBuyLeg,
  tradeBuySideMetrics,
  tradeSellSideMetrics,
} = require('../legPriceMetrics');

describe('legPriceMetrics', () => {
  test('costBasisPerShare = totalBuyCost / quantity (Bid 1,875 + Gebühren)', () => {
    const metrics = tradeBuySideMetrics({
      quantity: 500,
      grossAmount: 937.5,
      feeConfig: {},
    });
    expect(metrics).not.toBeNull();
    expect(metrics.bidPricePerShare).toBeCloseTo(1.875, 3);
    expect(metrics.totalBuyCost).toBe(945.5);
    expect(metrics.costBasisPerShare).toBeCloseTo(1.891, 3);
  });

  test('matches computeInvestorBuyLeg cost basis', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const fromLeg = costBasisPerShareFromBuyLeg(buyLeg);
    expect(fromLeg).toBeGreaterThan(0);
    const pieces = Math.floor(1000 / fromLeg);
    expect(pieces).toBe(buyLeg.quantity);
  });

  test('net sell price per share after fees', () => {
    const sellM = tradeSellSideMetrics({
      quantity: 98,
      grossAmount: 294,
      feeConfig: {},
    });
    expect(sellM.netSellAmount).toBeLessThanOrEqual(294);
    expect(sellM.netSellPricePerShare).toBeLessThan(sellM.askPricePerShare);
  });
});
