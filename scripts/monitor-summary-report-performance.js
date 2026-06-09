#!/usr/bin/env node
'use strict';

/**
 * Monitor: Summary Report trades page performance baseline (ADR-016 Phase 4.2).
 *
 * Required env: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
 * Optional:
 * - SUMMARY_REPORT_BENCH_PAGE_SIZE (default 100)
 * - SUMMARY_REPORT_BENCH_MAX_MS (default 8000)
 */

const pageSize = Number(process.env.SUMMARY_REPORT_BENCH_PAGE_SIZE || 100);
const maxMs = Number(process.env.SUMMARY_REPORT_BENCH_MAX_MS || 8000);

function normalizeParseBase(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.endsWith('/parse') ? trimmed : `${trimmed}/parse`;
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL);
  const appId = process.env.PARSE_APP_ID;
  const masterKey = process.env.PARSE_MASTER_KEY;

  if (!parseBase || !appId || !masterKey) {
    throw new Error('Missing required env vars: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY');
  }

  const response = await fetch(`${parseBase}/functions/benchmarkSummaryReportTradesPage`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
    },
    body: JSON.stringify({ pageSize, maxDurationMs: maxMs }),
  });

  const json = await response.json();
  if (!response.ok || json.error) {
    throw new Error(`Parse function call failed (${response.status}): ${JSON.stringify(json)}`);
  }

  const result = json.result || {};
  const durationMs = Number(result.durationMs ?? -1);
  const overall = String(result.overall || 'unknown');
  const itemCount = Number(result.itemCount ?? 0);
  const total = Number(result.total ?? 0);
  const checkedAt = result.checkedAt || new Date().toISOString();

  console.log(`checked_at=${checkedAt}`);
  console.log(`overall=${overall}`);
  console.log(`duration_ms=${durationMs}`);
  console.log(`max_duration_ms=${maxMs}`);
  console.log(`page_size=${pageSize}`);
  console.log(`item_count=${itemCount}`);
  console.log(`total_trades=${total}`);

  if (durationMs < 0) {
    throw new Error('Summary report benchmark missing durationMs');
  }

  if (durationMs > maxMs) {
    throw new Error(`Summary report slow: duration_ms=${durationMs} > max=${maxMs}`);
  }

  if (overall !== 'healthy') {
    throw new Error(`Summary report benchmark overall=${overall}`);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
