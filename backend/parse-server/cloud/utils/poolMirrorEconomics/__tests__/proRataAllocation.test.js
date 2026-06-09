'use strict';

const {
  computeTradeLevelPoolBuyTotals,
  computeTradeLevelPoolBuyTotalsFromBid,
  allocateProRataByInvestmentCapital,
} = require('../proRataAllocation');
const { DEFAULT_CONFIG } = require('../../configHelper/defaultConfig');

describe('proRataAllocation', () => {
  test('Residual 0,80 € auf 1000/3000 → 0,20 € / 0,60 €', () => {
    const tradeTotals = {
      impliedBuyQuantityFromPool: 100,
      poolCapitalAllocated: 3999.2,
      poolResidualTotal: 0.8,
      poolReservedCapitalTotal: 4000,
    };
    const rows = allocateProRataByInvestmentCapital([1000, 3000], tradeTotals);
    expect(rows).toHaveLength(2);
    expect(rows[0].residualAmount).toBe(0.2);
    expect(rows[1].residualAmount).toBe(0.6);
    expect(rows[0].poolCapitalAllocated).toBe(999.8);
    expect(rows[1].poolCapitalAllocated).toBe(2999.4);
    expect(rows[0].poolPieces).toBe(25);
    expect(rows[1].poolPieces).toBe(75);
    expect(
      round2(rows[0].poolCapitalAllocated + rows[0].residualAmount),
    ).toBe(1000);
    expect(
      round2(rows[1].poolCapitalAllocated + rows[1].residualAmount),
    ).toBe(3000);
  });

  test('computeTradeLevelPoolBuyTotals: 4000 @ 10 € → 400 Stück, Rest 0', () => {
    const totals = computeTradeLevelPoolBuyTotals(4000, 10);
    expect(totals.impliedBuyQuantityFromPool).toBe(400);
    expect(totals.poolCapitalAllocated).toBe(4000);
    expect(totals.poolResidualTotal).toBe(0);
  });

  test('computeTradeLevelPoolBuyTotalsFromBid: GS4GLEF 3000 @ 3,74 → 797 Stück, Rest 3,28', () => {
    const totals = computeTradeLevelPoolBuyTotalsFromBid(3000, 3.74, {});
    expect(totals.impliedBuyQuantityFromPool).toBe(797);
    expect(totals.poolCapitalAllocated).toBe(2996.72);
    expect(totals.poolResidualTotal).toBe(3.28);
    expect(totals.costBasisPerShare).toBe(3.7625);
  });

  test('computeTradeLevelPoolBuyTotalsFromBid: kleiner Trader-Bid — nicht Trader-Einstand für Stückzahl', () => {
    const feeConfig = DEFAULT_CONFIG.financial;
    const bid = 1.89007;
    const totals = computeTradeLevelPoolBuyTotalsFromBid(4000, bid, feeConfig);
    expect(totals.impliedBuyQuantityFromPool).toBe(2105);
    expect(totals.costBasisPerShare).toBe(1.9009);
    expect(totals.poolCapitalAllocated).toBe(3999.5);
    expect(totals.poolResidualTotal).toBe(0.5);
  });
});

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}
