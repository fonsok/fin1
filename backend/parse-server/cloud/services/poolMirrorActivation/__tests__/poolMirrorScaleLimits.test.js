'use strict';

const {
  DEFAULT_CREDIT_NOTE_INLINE_BREAKDOWN_MAX,
  DEFAULT_SUMMARY_REPORT_INLINE_PARTICIPATIONS_MAX,
  readSettlementParticipationBatchSize,
  shouldInlineCreditNoteBreakdown,
  shouldInlineSummaryReportParticipations,
} = require('../poolMirrorScaleLimits');

describe('poolMirrorScaleLimits', () => {
  test('defaults support large mirror trades', () => {
    expect(DEFAULT_CREDIT_NOTE_INLINE_BREAKDOWN_MAX).toBe(50);
    expect(DEFAULT_SUMMARY_REPORT_INLINE_PARTICIPATIONS_MAX).toBe(50);
    expect(readSettlementParticipationBatchSize()).toBeGreaterThan(0);
  });

  test('shouldInline helpers compare against caps', () => {
    expect(shouldInlineCreditNoteBreakdown(50)).toBe(true);
    expect(shouldInlineCreditNoteBreakdown(51)).toBe(false);
    expect(shouldInlineSummaryReportParticipations(50)).toBe(true);
    expect(shouldInlineSummaryReportParticipations(51)).toBe(false);
  });
});
