'use strict';

const { computeInvestorBuyLeg } = require('../accountingHelper/legs');
const {
  floorPoolPiecesFromCapital,
  aggregatePoolInvestmentEconomics,
  poolSellQuantityForTraderSellFraction,
  computeInvestorPartialSellDelta,
} = require('../poolMirrorEconomics');

describe('poolMirrorEconomics', () => {
  test('computeInvestorPartialSellDelta uses legs.js (mit Gebühren → weniger Stück als reines floor)', () => {
    const delta = computeInvestorPartialSellDelta({
      investmentCapital: 1000,
      tradeBuyPrice: 2.02,
      tradeSellPrice: 3,
      sellFraction: 0.2,
      commissionRate: 0.11,
      feeConfig: {},
    });
    expect(delta).not.toBeNull();
    expect(delta.sellLeg.quantity).toBeGreaterThan(0);
    expect(delta.sellLeg.quantity).toBeLessThanOrEqual(99);
    expect(delta.buyLeg.amount).toBeGreaterThan(0);
    expect(delta.grossProfit).toBeDefined();
  });
});

describe('aggregatePoolInvestmentEconomics (shared with Summary)', () => {
  test('matches legs.js 1000 @ 2.02 with fees', () => {
    const buyLeg = computeInvestorBuyLeg(1000, 2.02, {});
    const econ = aggregatePoolInvestmentEconomics(
      [{ investmentStatus: 'active', investmentCapital: 1000, investorId: 'u1' }],
      2.02,
      { buyQuantity: 1000, soldQuantity: 200 },
      { feeConfig: {}, sellPrice: 3 },
    );
    expect(econ.impliedBuyQuantityFromPool).toBe(buyLeg.quantity);
    expect(econ.poolCapitalAllocated).toBe(buyLeg.amount);
    expect(econ.poolResidualTotal).toBe(buyLeg.residualAmount);
    expect(econ.poolSoldQuantityDerived).toBe(98);
  });

  test('poolSellQuantityForTraderSellFraction', () => {
    expect(poolSellQuantityForTraderSellFraction(495, 1)).toBe(495);
    expect(poolSellQuantityForTraderSellFraction(495, 200 / 1000)).toBe(99);
  });
});
