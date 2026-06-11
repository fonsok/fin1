'use strict';

const { validateCommissionRateOrdering } = require('../validateConfigValue');

describe('validateCommissionRateOrdering', () => {
  const financial = { traderCommissionRate: 0.05, appCommissionRate: 0.05 };

  test('allows combined rate at 100%', () => {
    expect(validateCommissionRateOrdering('traderCommissionRate', 0.5, financial).valid).toBe(true);
    expect(validateCommissionRateOrdering('appCommissionRate', 0.5, {
      traderCommissionRate: 0.5,
      appCommissionRate: 0.05,
    }).valid).toBe(true);
  });

  test('rejects combined rate above 100%', () => {
    const result = validateCommissionRateOrdering('appCommissionRate', 0.6, {
      traderCommissionRate: 0.5,
      appCommissionRate: 0.05,
    });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('100 %');
  });

  test('ignores unrelated parameters', () => {
    expect(validateCommissionRateOrdering('minimumCashReserve', 100, financial).valid).toBe(true);
  });
});
