'use strict';

const { investorPoolPiecesAtCostBasis } = require('../poolMirrorInvestorDelta');
const { aggregatePoolInvestmentEconomics } = require('../poolMirrorEconomics');

describe('investorPoolPiecesAtCostBasis', () => {
  test('3000 / 3,78 = 793 Stück, Residual 2,46 €', () => {
    expect(investorPoolPiecesAtCostBasis(3000, 3.78)).toEqual({
      poolPieces: 793,
      activeAtBasis: 2997.54,
      residualAmount: 2.46,
    });
  });

  test('aggregatePoolInvestmentEconomics matches per-investor floor @ Einstand', () => {
    const participations = [{
      investorId: 'inv-1',
      investmentStatus: 'active',
      investmentCapital: 3000,
    }];
    const econ = aggregatePoolInvestmentEconomics(
      participations,
      3.78,
      null,
      { costBasisPerShare: 3.78 },
    );
    expect(econ.impliedBuyQuantityFromPool).toBe(793);
    expect(econ.poolCapitalAllocated).toBe(2997.54);
    expect(econ.poolResidualTotal).toBe(2.46);
  });

  test('trade-level einlage uses Σ Stück × round2(Einstand) with traderReference', () => {
    const participations = [{
      investorId: 'inv-1',
      investmentStatus: 'active',
      investmentCapital: 3000,
      buySnapshot: {
        poolPieces: 793,
        poolCapitalAllocated: 2997.54,
        investmentAmount: 3000,
        residualAmount: 2.46,
      },
    }];
    const econ = aggregatePoolInvestmentEconomics(
      participations,
      3.78,
      { buyQuantity: 1000, soldQuantity: 0, costBasisPerShare: 3.78 },
      { costBasisPerShare: 3.78 },
    );
    expect(econ.impliedBuyQuantityFromPool).toBe(793);
    expect(econ.poolCapitalAllocated).toBe(2997.54);
    expect(econ.poolResidualTotal).toBe(2.46);
  });
});
