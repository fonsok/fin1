'use strict';

const { calculateOrderFees } = require('../helpers');
const { DEFAULT_CONFIG } = require('../configHelper/defaultConfig');
const {
  assertCentAlignedEuro,
  euroToCents,
  feeFromRatioEuro,
  sumEuroComponents,
} = require('../accountingHelper/moneyCents');

describe('calculateOrderFees — P3c-1b cent-normalized', () => {
  const D = DEFAULT_CONFIG.financial;

  function expectCentAlignedFees(fees) {
    expect(assertCentAlignedEuro(fees.orderFee)).toBe(fees.orderFee);
    expect(assertCentAlignedEuro(fees.exchangeFee)).toBe(fees.exchangeFee);
    expect(assertCentAlignedEuro(fees.foreignCosts)).toBe(fees.foreignCosts);
    expect(assertCentAlignedEuro(fees.totalFees)).toBe(fees.totalFees);
    expect(fees.totalFees).toBe(
      sumEuroComponents(fees.orderFee, fees.exchangeFee, fees.foreignCosts),
    );
  }

  test.each([
    [0, false],
    [0, true],
    [1000, true],
    [10000, false],
    [2465.64, true],
    [333.33, true],
    [1600, false],
    [988.5, true],
  ])('gross=%p foreign=%p returns cent-aligned components', (gross, isForeign) => {
    const fees = calculateOrderFees(gross, isForeign);
    expectCentAlignedFees(fees);
  });

  test('3000 foreign matches investor statement reference (18 € total)', () => {
    const fees = calculateOrderFees(3000, true);
    expect(fees.totalFees).toBe(18);
    expectCentAlignedFees(fees);
  });

  test('matches legacy feeFromRatioEuro building blocks', () => {
    const gross = 2465.64;
    const orderFee = feeFromRatioEuro(gross, D.orderFeeRate, D.orderFeeMin, D.orderFeeMax);
    const exchangeFee = feeFromRatioEuro(
      gross,
      D.exchangeFeeRate,
      D.exchangeFeeMin,
      D.exchangeFeeMax,
    );
    const foreign = euroToCents(D.foreignCosts) / 100;
    const fees = calculateOrderFees(gross, true);
    expect(fees.orderFee).toBe(orderFee);
    expect(fees.exchangeFee).toBe(exchangeFee);
    expect(fees.foreignCosts).toBe(foreign);
    expect(fees.totalFees).toBe(sumEuroComponents(orderFee, exchangeFee, foreign));
  });
});
