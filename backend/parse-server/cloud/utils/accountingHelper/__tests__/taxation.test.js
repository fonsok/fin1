'use strict';

const { calculateWithholdingBundle } = require('../taxation');

describe('taxation helper', () => {
  test('treats invalid tax mode as customer self reporting (fail-safe)', () => {
    const result = calculateWithholdingBundle({
      taxableAmount: 100,
      taxConfig: {
        taxCollectionMode: 'invalid_mode',
        withholdingTaxRate: 0.25,
        solidaritySurchargeRate: 0.055,
      },
      userProfile: null,
    });

    expect(result.taxCollectionMode).toBe('customer_self_reports');
    expect(result.totalTax).toBe(0);
  });

  test('returns zero taxes when mode is customer_self_reports', () => {
    const result = calculateWithholdingBundle({
      taxableAmount: 100,
      taxConfig: {
        taxCollectionMode: 'customer_self_reports',
        withholdingTaxRate: 0.25,
        solidaritySurchargeRate: 0.055,
      },
      userProfile: null,
    });

    expect(result.totalTax).toBe(0);
    expect(result.withholdingTax).toBe(0);
    expect(result.solidaritySurcharge).toBe(0);
    expect(result.churchTax).toBe(0);
  });

  test('calculates withholding + soli and no church tax without religion', () => {
    const mockProfile = {
      get: (key) => {
        const values = {
          state: 'Berlin',
          country: 'Deutschland',
        };
        return values[key];
      },
    };

    const result = calculateWithholdingBundle({
      taxableAmount: 200,
      taxConfig: {
        taxCollectionMode: 'platform_withholds',
        withholdingTaxRate: 0.25,
        solidaritySurchargeRate: 0.055,
      },
      userProfile: mockProfile,
    });

    expect(result.withholdingTax).toBe(50);
    expect(result.solidaritySurcharge).toBe(2.75);
    expect(result.churchTax).toBe(0);
    expect(result.totalTax).toBe(52.75);
  });

  test('uses 8% church tax in Bayern/Baden-Wuerttemberg', () => {
    const mockProfile = {
      get: (key) => {
        const values = {
          religion: 'katholisch',
          state: 'Bayern',
          country: 'Deutschland',
        };
        return values[key];
      },
    };

    const result = calculateWithholdingBundle({
      taxableAmount: 100,
      taxConfig: {
        taxCollectionMode: 'platform_withholds',
        withholdingTaxRate: 0.25,
        solidaritySurchargeRate: 0.055,
      },
      userProfile: mockProfile,
    });

    expect(result.withholdingTax).toBe(25);
    expect(result.churchTax).toBe(2);
    expect(result.totalTax).toBe(28.38);
  });
});
