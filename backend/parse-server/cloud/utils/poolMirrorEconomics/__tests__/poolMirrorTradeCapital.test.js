'use strict';

const {
  resolvePoolMirrorTradeCapitalAllocated,
  applyTradeLevelPoolCapitalTotals,
} = require('../resolvePoolMirrorState');

describe('pool mirror trade-level capital (Σ Stück × Einstand Anzeige)', () => {
  test('432 × 6,94 € = 2.998,08 € Pool-Einlage', () => {
    expect(resolvePoolMirrorTradeCapitalAllocated(432, 6.93769)).toBe(2998.08);
    expect(resolvePoolMirrorTradeCapitalAllocated(432, 6.94)).toBe(2998.08);
  });

  test('applyTradeLevelPoolCapitalTotals derives residual from reserved − einlage', () => {
    const econ = applyTradeLevelPoolCapitalTotals({
      poolReservedCapitalTotal: 3000,
      impliedBuyQuantityFromPool: 432,
      poolCapitalAllocated: 2997.09,
      poolResidualTotal: 2.91,
    }, 6.94);
    expect(econ.poolCapitalAllocated).toBe(2998.08);
    expect(econ.poolResidualTotal).toBe(1.92);
  });
});
