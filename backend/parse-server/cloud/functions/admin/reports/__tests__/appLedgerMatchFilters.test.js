'use strict';

const {
  createLedgerEntryMatchers,
  matchesReferenceSearch,
  matchesAmountRange,
} = require('../appLedgerMatchFilters');
const { parseAppLedgerListFilters, requiresMemoryFilter } = require('../appLedgerListFilters');

describe('appLedgerListFilters', () => {
  test('parseAppLedgerListFilters normalizes amount range', () => {
    const filters = parseAppLedgerListFilters({
      amountMin: '100',
      amountMax: '50',
      limit: 9999,
      skip: -1,
    });
    expect(filters.amountMin).toBe(100);
    expect(filters.amountMax).toBe(100);
    expect(filters.limit).toBe(500);
    expect(filters.skip).toBe(0);
  });

  test('requiresMemoryFilter for fuzzy user and beleg search', () => {
    expect(requiresMemoryFilter(parseAppLedgerListFilters({ userId: 'max@example.com' }))).toBe(true);
    expect(requiresMemoryFilter(parseAppLedgerListFilters({ referenceSearch: 'WDR-2026' }))).toBe(true);
    expect(requiresMemoryFilter(parseAppLedgerListFilters({ userId: 'abc1234567' }))).toBe(false);
  });
});

describe('appLedgerMatchFilters', () => {
  const baseEntry = {
    id: 'e1',
    account: 'CLT-LIAB-AVA',
    side: 'debit',
    amount: 1500,
    userId: 'user-1',
    userRole: 'investor',
    transactionType: 'investmentEscrow',
    referenceId: 'ref-abc',
    referenceType: 'investment',
    description: 'Test',
    createdAt: '2026-01-15T12:00:00.000Z',
    metadata: {
      businessReference: 'INV-2026-00042',
      referenceDocumentNumber: 'WDR-2026-0000001',
      userCustomerNumber: 'C-1001',
      userDisplayName: 'Max Mustermann',
    },
  };

  test('matchesReferenceSearch on business and document fields', () => {
    expect(matchesReferenceSearch(baseEntry, 'wdr-2026')).toBe(true);
    expect(matchesReferenceSearch(baseEntry, 'inv-2026')).toBe(true);
    expect(matchesReferenceSearch(baseEntry, 'missing')).toBe(false);
  });

  test('matchesAmountRange on line amount', () => {
    expect(matchesAmountRange(baseEntry, 1000, 2000)).toBe(true);
    expect(matchesAmountRange(baseEntry, 2000, null)).toBe(false);
    expect(matchesAmountRange(baseEntry, null, 1000)).toBe(false);
  });

  test('createLedgerEntryMatchers combines user, amount, and reference filters', () => {
    const { matchesFilters } = createLedgerEntryMatchers({
      account: null,
      transactionType: null,
      dateFrom: null,
      dateTo: null,
      userId: 'c-1001',
      amountMin: 1000,
      amountMax: 2000,
      referenceSearch: 'WDR-2026',
    });
    expect(matchesFilters(baseEntry)).toBe(true);
  });
});
