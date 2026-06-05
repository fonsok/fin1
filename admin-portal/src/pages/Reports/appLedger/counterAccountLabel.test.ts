import { describe, it, expect } from 'vitest';
import {
  formatCounterAccountColumnLabel,
  formatLedgerAccountCodeLabel,
  resolveCounterAccountDisplaySegments,
  resolveCounterAccountLabel,
} from './counterAccountLabel';

const catalog = new Map([
  ['CLT-LIAB-AVA', { name: 'Kundenguthaben – Available', externalAccountNumber: '1591' }],
  ['CLT-LIAB-RSV', { name: 'Kundenguthaben – Reserved', externalAccountNumber: '1592' }],
  ['PLT-CLR-GEN', { name: 'Verrechnungskonto Appgebühr', externalAccountNumber: '1360' }],
]);

describe('counterAccountLabel', () => {
  it('formats a single counter account with number, name, and internal code', () => {
    expect(
      formatCounterAccountColumnLabel(
        resolveCounterAccountLabel(
          'CLT-LIAB-AVA',
          'investmentEscrow',
          undefined,
          undefined,
          'reserve',
        ),
        catalog,
      ),
    ).toBe('1592 Kundenguthaben – Reserved (CLT-LIAB-RSV)');
  });

  it('builds display segments for UI rendering', () => {
    expect(
      resolveCounterAccountDisplaySegments('CLT-LIAB-RSV', catalog),
    ).toEqual([
      {
        internalCode: 'CLT-LIAB-RSV',
        primaryLabel: '1592 Kundenguthaben – Reserved',
        hasCatalogEntry: true,
      },
    ]);
  });

  it('formats multiple counter accounts comma-separated', () => {
    expect(
      formatCounterAccountColumnLabel('PLT-REV-PSC, PLT-TAX-VAT', catalog),
    ).toBe('PLT-REV-PSC, PLT-TAX-VAT');
  });

  it('formats compound counter accounts joined with plus', () => {
    expect(
      formatCounterAccountColumnLabel('CLT-LIAB-PTR + CLT-LIAB-AVA', catalog),
    ).toBe('CLT-LIAB-PTR, 1591 Kundenguthaben – Available (CLT-LIAB-AVA)');
  });

  it('falls back to internal code when catalog entry is missing', () => {
    expect(formatLedgerAccountCodeLabel('PLT-REV-PSC', catalog)).toBe('PLT-REV-PSC');
  });
});
