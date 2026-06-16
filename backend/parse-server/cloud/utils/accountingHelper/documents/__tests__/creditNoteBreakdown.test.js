'use strict';

const { buildCreditNoteInvestorBreakdownMetadata } = require('../creditNoteBreakdown');

describe('creditNoteBreakdown', () => {
  const originalEnv = process.env.CREDIT_NOTE_INLINE_BREAKDOWN_MAX;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.CREDIT_NOTE_INLINE_BREAKDOWN_MAX;
    } else {
      process.env.CREDIT_NOTE_INLINE_BREAKDOWN_MAX = originalEnv;
    }
  });

  test('keeps inline rows when count is within cap', () => {
    process.env.CREDIT_NOTE_INLINE_BREAKDOWN_MAX = '3';
    const rows = [
      { investorId: 'i1', investmentId: 'inv1', grossProfit: 10, commission: 1 },
      { investorId: 'i2', investmentId: 'inv2', grossProfit: 20, commission: 2 },
    ];
    const meta = buildCreditNoteInvestorBreakdownMetadata(rows);
    expect(meta.investorCount).toBe(2);
    expect(meta.investorBreakdownTruncated).toBe(false);
    expect(meta.investorBreakdown).toHaveLength(2);
    expect(meta.investorBreakdown[0].commission).toBe(1);
  });

  test('summary only when count exceeds cap', () => {
    process.env.CREDIT_NOTE_INLINE_BREAKDOWN_MAX = '2';
    const rows = [
      { investorId: 'i1', investmentId: 'inv1', grossProfit: 10, commission: 1 },
      { investorId: 'i2', investmentId: 'inv2', grossProfit: 20, commission: 2 },
      { investorId: 'i3', investmentId: 'inv3', grossProfit: 30, commission: 3 },
    ];
    const meta = buildCreditNoteInvestorBreakdownMetadata(rows);
    expect(meta.investorCount).toBe(3);
    expect(meta.investorBreakdownTruncated).toBe(true);
    expect(meta.investorBreakdown).toEqual([]);
  });
});
