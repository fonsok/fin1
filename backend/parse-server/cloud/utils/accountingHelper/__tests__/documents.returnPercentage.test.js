'use strict';

const {
  computeCollectionBillReturnPercentage,
  assertCollectionBillReturnPercentageInvariant,
} = require('../documents');

describe('documents helper return percentage', () => {
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
