import { describe, it, expect } from 'vitest';
import {
  computeRatesFromPreset,
  detectPresetFromRates,
  formatCommissionRatesSummary,
  ratesAreEqual,
  validateCommissionRates,
} from './commissionRateTraderApp';

describe('commissionRateTraderApp', () => {
  it('computes equal split from total', () => {
    expect(computeRatesFromPreset(0.1, 0.5)).toEqual({
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.05,
      appCommissionRate: 0.05,
    });
  });

  it('detects preset from current rates', () => {
    expect(
      detectPresetFromRates({
        investorCommissionRateTotal: 0.1,
        traderCommissionRate: 0.05,
        appCommissionRate: 0.05,
      }),
    ).toBe('equal_50_50');
  });

  it('validates exact sum', () => {
    expect(
      validateCommissionRates({
        investorCommissionRateTotal: 0.1,
        traderCommissionRate: 0.06,
        appCommissionRate: 0.05,
      }),
    ).toContain('Summe muss exakt');
  });

  it('formats summary for display', () => {
    expect(
      formatCommissionRatesSummary({
        investorCommissionRateTotal: 0.1,
        traderCommissionRate: 0.05,
        appCommissionRate: 0.05,
      }),
    ).toBe('10 % gesamt — Trader 5 % · App 5 %');
  });

  it('compares rate bundles', () => {
    const a = {
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.05,
      appCommissionRate: 0.05,
    };
    const b = computeRatesFromPreset(0.1, 0.5);
    expect(ratesAreEqual(a, b)).toBe(true);
  });
});
