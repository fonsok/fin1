'use strict';

const {
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
} = require('../documents');

describe('documents helper return percentage', () => {
  const knownRegressionFixture = {
    tradeId: 'FxKeEPyohH',
    investmentId: 'qQmJ4NJHcA',
    netProfit: 373.76,
    buyLeg: null,
    investmentCapital: 1000,
    expectedReturnPercentage: 37.38,
  };

  test('uses buy leg amount + fees as invested amount', () => {
    const result = computeCollectionBillReturnPercentage({
      netProfit: 100,
      buyLeg: {
        amount: 1000,
        fees: { totalFees: 10 },
      },
      investmentCapital: 9999, // should be ignored when buyLeg is available
    });

    expect(result).toBe(9.9);
  });

  test('falls back to investment capital when buy leg is missing', () => {
    const result = computeCollectionBillReturnPercentage({
      netProfit: 50,
      buyLeg: null,
      investmentCapital: 1000,
    });

    expect(result).toBe(5);
  });

  test('known regression fixture keeps expected return percentage stable', () => {
    const result = computeCollectionBillReturnPercentage({
      netProfit: knownRegressionFixture.netProfit,
      buyLeg: knownRegressionFixture.buyLeg,
      investmentCapital: knownRegressionFixture.investmentCapital,
    });

    expect(result).toBe(knownRegressionFixture.expectedReturnPercentage);
  });

  test('returns null when no valid denominator exists', () => {
    const result = computeCollectionBillReturnPercentage({
      netProfit: 50,
      buyLeg: null,
      investmentCapital: 0,
    });

    expect(result).toBeNull();
  });

  test('invariant passes when canonical return percentage is present', () => {
    expect(() => {
      assertCollectionBillReturnPercentageInvariant(12.34, {
        tradeId: 'T1',
        investmentId: 'I1',
      });
    }).not.toThrow();
  });

  test('invariant throws when canonical return percentage is missing', () => {
    expect(() => {
      assertCollectionBillReturnPercentageInvariant(null, {
        tradeId: 'T1',
        investmentId: 'I1',
      });
    }).toThrow(/missing canonical returnPercentage/i);
  });
});
