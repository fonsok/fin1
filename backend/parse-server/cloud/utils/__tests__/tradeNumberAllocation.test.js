'use strict';

const {
  getTradeNumberCalendarYear,
  formatTradeNumberForDisplay,
  resolveTradeNumberYear,
} = require('../tradeNumberAllocation');

describe('tradeNumberAllocation', () => {
  test('getTradeNumberCalendarYear uses Europe/Berlin', () => {
    // 2025-12-31 23:30 UTC = 2026-01-01 00:30 Berlin
    const year = getTradeNumberCalendarYear(new Date('2025-12-31T23:30:00.000Z'));
    expect(year).toBe(2026);
  });

  test('formatTradeNumberForDisplay renders YYYY-NNN', () => {
    expect(formatTradeNumberForDisplay(1, 2026)).toBe('2026-001');
    expect(formatTradeNumberForDisplay(42, 2025)).toBe('2025-042');
    expect(formatTradeNumberForDisplay(0, 2026)).toBe('');
  });

  test('resolveTradeNumberYear prefers explicit field', () => {
    const trade = {
      get(key) {
        return key === 'tradeNumberYear' ? 2024 : undefined;
      },
    };
    expect(resolveTradeNumberYear(trade)).toBe(2024);
  });

  test('resolveTradeNumberYear falls back to createdAt', () => {
    const trade = {
      get(key) {
        if (key === 'createdAt') return new Date('2026-03-15T10:00:00.000Z');
        return undefined;
      },
    };
    expect(resolveTradeNumberYear(trade)).toBe(2026);
  });

  test('buildTradeNumberCounterKey scopes by trader and year', () => {
    const { buildTradeNumberCounterKey } = require('../tradeNumberAllocation');
    expect(buildTradeNumberCounterKey('trader-abc', 2026)).toBe('Trade::tradeNumber::trader-abc::2026');
  });

  test('resolveTradeNumberPresentation builds label and filename token', () => {
    const { resolveTradeNumberPresentation } = require('../tradeNumberAllocation');
    const trade = {
      get(key) {
        if (key === 'tradeNumber') return 7;
        if (key === 'tradeNumberYear') return 2026;
        return undefined;
      },
    };
    expect(resolveTradeNumberPresentation(trade)).toEqual({
      tradeNumber: 7,
      tradeNumberYear: 2026,
      formattedTradeNumber: '2026-007',
      filenameToken: '2026-007',
      label: 'Trade #2026-007',
    });
  });
});
