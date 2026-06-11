import { describe, it, expect } from 'vitest';
import { PARAMETER_DEFINITIONS } from './parameterDefinitions';
import { sortConfigEntriesAlphabetically, sortFinancialConfigEntries, sortTaxConfigEntries } from './configurationSort';

describe('sortConfigEntriesAlphabetically', () => {
  it('sorts visible financial parameters by German display name', () => {
    const entries = Object.entries(PARAMETER_DEFINITIONS).filter(
      ([, def]) => def.category === 'financial' && !def.hiddenInParameterList,
    );
    const sorted = sortFinancialConfigEntries(entries).map(([key]) => key);

    expect(sorted).not.toContain('investorCommissionRateTotal');
    expect(sorted).not.toContain('traderCommissionRate');
    expect(sorted).not.toContain('appCommissionRate');
    expect(sorted.length).toBeGreaterThan(0);
  });

  it('sorts financial parameters by German display name', () => {
    const entries = Object.entries(PARAMETER_DEFINITIONS).filter(([, def]) => def.category === 'financial');
    const sorted = sortConfigEntriesAlphabetically(entries).map(([, def]) => def.displayName);

    expect(sorted[0]?.localeCompare(sorted[1] ?? '', 'de', { sensitivity: 'base' })).toBeLessThanOrEqual(0);
    expect(sorted).toContain('Mindestinvestmentbetrag');
    expect(sorted).toContain('Maximuminvestmentbetrag');
  });

  it('keeps fixed order for tax parameters', () => {
    const entries = Object.entries(PARAMETER_DEFINITIONS).filter(([, def]) => def.category === 'tax');
    const sorted = sortTaxConfigEntries(entries).map(([, def]) => def.displayName);

    expect(sorted).toEqual([
      'Umsatzsteuer (MwSt.)',
      'Abgeltungsteuer',
      'Abgeltungsteuersatz',
      'Solidaritätszuschlag',
    ]);
  });
});
