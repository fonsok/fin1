'use strict';

const { handleGetSummaryReportTradesPage } = require('./reports/summaryReportRegister');

/**
 * Performance baseline for Summary Report trades page (Phase 4.2).
 */
async function handleBenchmarkSummaryReportTradesPage(request) {
  const pageSize = Math.min(100, Math.max(1, Number(request.params?.pageSize || 100)));
  const maxDurationMs = Math.max(500, Number(request.params?.maxDurationMs || 8000));

  const t0 = Date.now();
  const result = await handleGetSummaryReportTradesPage({
    params: {
      page: 0,
      pageSize,
      returnFilter: 'any',
    },
  });
  const durationMs = Date.now() - t0;
  const itemCount = Array.isArray(result?.items) ? result.items.length : 0;

  return {
    overall: durationMs <= maxDurationMs ? 'healthy' : 'degraded',
    durationMs,
    maxDurationMs,
    pageSize,
    itemCount,
    total: Number(result?.total || 0),
    searchMode: result?.searchMode || 'none',
    message: durationMs <= maxDurationMs
      ? `Summary report trades page OK (${durationMs}ms)`
      : `Summary report trades page slow: ${durationMs}ms > ${maxDurationMs}ms`,
    checkedAt: new Date().toISOString(),
  };
}

module.exports = {
  handleBenchmarkSummaryReportTradesPage,
};
