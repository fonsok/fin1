'use strict';

const { DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE } = require('./poolMirrorLimits');

/** Inline investor rows embedded in trader credit note metadata (above → summary only). */
const DEFAULT_CREDIT_NOTE_INLINE_BREAKDOWN_MAX = 50;

/** Inline pool participations in Summary Report trade rows (above → paginated API). */
const DEFAULT_SUMMARY_REPORT_INLINE_PARTICIPATIONS_MAX = 50;

/** Investors settled concurrently per batch during pool settlement. */
const DEFAULT_SETTLEMENT_PARTICIPATION_BATCH_SIZE = 25;

const DEFAULT_PARTICIPATIONS_PAGE_SIZE = 50;
const MAX_PARTICIPATIONS_PAGE_SIZE = 200;

function readPositiveIntEnv(name, fallback) {
  const raw = Number(process.env[name] || fallback);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : fallback;
}

function readCreditNoteInlineBreakdownMax() {
  return readPositiveIntEnv(
    'CREDIT_NOTE_INLINE_BREAKDOWN_MAX',
    DEFAULT_CREDIT_NOTE_INLINE_BREAKDOWN_MAX,
  );
}

function readSummaryReportInlineParticipationsMax() {
  return readPositiveIntEnv(
    'SUMMARY_REPORT_INLINE_PARTICIPATIONS_MAX',
    DEFAULT_SUMMARY_REPORT_INLINE_PARTICIPATIONS_MAX,
  );
}

function readSettlementParticipationBatchSize() {
  const batch = readPositiveIntEnv(
    'SETTLEMENT_PARTICIPATION_BATCH_SIZE',
    DEFAULT_SETTLEMENT_PARTICIPATION_BATCH_SIZE,
  );
  return Math.min(batch, DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE);
}

function readParticipationsPageSize(requested) {
  const raw = Number(requested);
  const size = Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : DEFAULT_PARTICIPATIONS_PAGE_SIZE;
  return Math.min(MAX_PARTICIPATIONS_PAGE_SIZE, Math.max(1, size));
}

function shouldInlineCreditNoteBreakdown(investorCount) {
  return Number(investorCount || 0) <= readCreditNoteInlineBreakdownMax();
}

function shouldInlineSummaryReportParticipations(participationCount) {
  return Number(participationCount || 0) <= readSummaryReportInlineParticipationsMax();
}

module.exports = {
  DEFAULT_CREDIT_NOTE_INLINE_BREAKDOWN_MAX,
  DEFAULT_SUMMARY_REPORT_INLINE_PARTICIPATIONS_MAX,
  DEFAULT_SETTLEMENT_PARTICIPATION_BATCH_SIZE,
  DEFAULT_PARTICIPATIONS_PAGE_SIZE,
  MAX_PARTICIPATIONS_PAGE_SIZE,
  readCreditNoteInlineBreakdownMax,
  readSummaryReportInlineParticipationsMax,
  readSettlementParticipationBatchSize,
  readParticipationsPageSize,
  shouldInlineCreditNoteBreakdown,
  shouldInlineSummaryReportParticipations,
};
