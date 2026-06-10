import { describe, expect, it } from 'vitest';
import { sortLedgerAccountsByExternalNumber } from './constants';

describe('sortLedgerAccountsByExternalNumber', () => {
  it('sorts by external account number ascending', () => {
    const accounts = [
      { code: 'PLT-LIAB-COM', name: 'Commission', externalAccountNumber: '1700' },
      { code: 'CLT-LIAB-AVA', name: 'Available', externalAccountNumber: '1591' },
      { code: 'PLT-CLR-GEN', name: 'Clearing', externalAccountNumber: '1360' },
    ];

    expect(sortLedgerAccountsByExternalNumber(accounts).map((a) => a.externalAccountNumber)).toEqual([
      '1360',
      '1591',
      '1700',
    ]);
  });

  it('places accounts without external number after numbered accounts', () => {
    const accounts = [
      { code: 'ZZZ', name: 'No number' },
      { code: 'CLT-LIAB-AVA', name: 'Available', externalAccountNumber: '1591' },
    ];

    expect(sortLedgerAccountsByExternalNumber(accounts).map((a) => a.code)).toEqual(['CLT-LIAB-AVA', 'ZZZ']);
  });
});
