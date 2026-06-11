'use strict';

const {
  validateCommissionRateBundle,
  formatCommissionRateBundle,
  normalizeCommissionRateBundle,
} = require('../commissionRateBundle');

describe('commissionRateBundle', () => {
  it('validates matching bundle', () => {
    const result = validateCommissionRateBundle({
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.05,
      appCommissionRate: 0.05,
    });
    expect(result.valid).toBe(true);
    expect(result.bundle).toEqual({
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.05,
      appCommissionRate: 0.05,
    });
  });

  it('rejects mismatched sum', () => {
    const result = validateCommissionRateBundle({
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.06,
      appCommissionRate: 0.05,
    });
    expect(result.valid).toBe(false);
  });

  it('formats bundle for notifications', () => {
    expect(
      formatCommissionRateBundle(normalizeCommissionRateBundle({
        investorCommissionRateTotal: 0.1,
        traderCommissionRate: 0.05,
        appCommissionRate: 0.05,
      })),
    ).toContain('10 % gesamt');
  });
});
