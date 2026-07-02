import { describe, expect, it } from 'vitest';
import {
  formatTradeNumber,
  formatTradeNumberHash,
  formatTradeNumberLabel,
  tradeNumberCalendarYear,
} from './tradeNumberFormat';

describe('tradeNumberFormat', () => {
  it('formats with explicit year', () => {
    expect(formatTradeNumber(1, 2026)).toBe('2026-001');
    expect(formatTradeNumberLabel(42, 2025)).toBe('Trade #2025-042');
    expect(formatTradeNumberHash(7, 2026)).toBe('#2026-007');
  });

  it('falls back to Berlin calendar year from reference date', () => {
    const year = tradeNumberCalendarYear(new Date('2026-03-15T12:00:00.000Z'));
    expect(year).toBe(2026);
    expect(formatTradeNumber(3, null, '2026-06-01')).toBe('2026-003');
  });

  it('returns empty for invalid numbers', () => {
    expect(formatTradeNumber(0, 2026)).toBe('');
    expect(formatTradeNumber(null, 2026)).toBe('');
  });
});
