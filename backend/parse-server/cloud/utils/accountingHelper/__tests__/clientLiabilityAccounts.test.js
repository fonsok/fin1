'use strict';

const {
  CLT_LIAB_PTR,
  CLT_LIAB_TRD_LEGACY,
  normalizeClientLiabilityAccount,
  expandLedgerAccountFilter,
} = require('../clientLiabilityAccounts');

describe('clientLiabilityAccounts', () => {
  test('normalizeClientLiabilityAccount maps legacy TRD to PTR', () => {
    expect(normalizeClientLiabilityAccount(CLT_LIAB_TRD_LEGACY)).toBe(CLT_LIAB_PTR);
    expect(normalizeClientLiabilityAccount(CLT_LIAB_PTR)).toBe(CLT_LIAB_PTR);
  });

  test('expandLedgerAccountFilter includes legacy for PTR filter', () => {
    expect(expandLedgerAccountFilter(CLT_LIAB_PTR)).toEqual([CLT_LIAB_PTR, CLT_LIAB_TRD_LEGACY]);
    expect(expandLedgerAccountFilter('CLT-LIAB-AVA')).toEqual(['CLT-LIAB-AVA']);
  });
});
