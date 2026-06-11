'use strict';

const { validateInvestorCommissionRateTotalMatch } = require('../validateConfigValue');

describe('validateInvestorCommissionRateTotalMatch', () => {
  const financial = {
    traderCommissionRate: 0.05,
    appCommissionRate: 0.05,
    investorCommissionRateTotal: 0.1,
  };

  test('allows split that equals total exactly', () => {
    expect(validateInvestorCommissionRateTotalMatch('traderCommissionRate', 0.06, {
      ...financial,
      appCommissionRate: 0.04,
      investorCommissionRateTotal: 0.1,
    }).valid).toBe(true);
  });

  test('rejects when sum differs from total', () => {
    const result = validateInvestorCommissionRateTotalMatch('appCommissionRate', 0.06, {
      traderCommissionRate: 0.05,
      appCommissionRate: 0.05,
      investorCommissionRateTotal: 0.1,
    });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('Gesamtprovision');
    expect(result.error).toContain('=');
  });

  test('validates when total parameter changes', () => {
    const result = validateInvestorCommissionRateTotalMatch('investorCommissionRateTotal', 0.12, financial);
    expect(result.valid).toBe(false);
  });

  test('ignores unrelated parameters', () => {
    expect(validateInvestorCommissionRateTotalMatch('minimumCashReserve', 100, financial).valid).toBe(true);
  });
});
