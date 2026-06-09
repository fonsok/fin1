#!/usr/bin/env bash
set -euo pipefail
export SUMMARY_REPORT_BENCH_PAGE_SIZE="${SUMMARY_REPORT_BENCH_PAGE_SIZE:-100}"
export SUMMARY_REPORT_BENCH_MAX_MS="${SUMMARY_REPORT_BENCH_MAX_MS:-8000}"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-parse-cloud-monitor.sh" \
  summary-report-performance-monitor monitor-summary-report-performance.js
