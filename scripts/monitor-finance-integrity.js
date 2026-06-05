#!/usr/bin/env node
'use strict';

/**
 * CI monitor: closed finance integrity rollup (`getFinanceIntegrityStatus`).
 * Includes live chain guard `paired_sell_investor_chain` and P0 `finance_prevention_indexes`.
 *
 * Required env:
 * - PARSE_SERVER_URL
 * - PARSE_APP_ID
 * - PARSE_MASTER_KEY
 */

function normalizeParseBase(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.endsWith('/parse') ? trimmed : `${trimmed}/parse`;
}

function emitOutput(name, value) {
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;
  const fs = require('fs');
  fs.appendFileSync(outputPath, `${name}=${String(value).replace(/\n/g, ' ')}\n`);
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL);
  const appId = process.env.PARSE_APP_ID;
  const masterKey = process.env.PARSE_MASTER_KEY;

  if (!parseBase || !appId || !masterKey) {
    throw new Error('Missing required env vars: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY');
  }

  const endpoint = `${parseBase}/functions/getFinanceIntegrityStatus`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
    },
    body: JSON.stringify({ settlementLimit: 50 }),
  });

  const rawText = await response.text();
  let json;
  try {
    json = JSON.parse(rawText);
  } catch (_) {
    throw new Error(
      `Parse function call returned non-JSON (${response.status}) from ${endpoint}: ${rawText.slice(0, 300)}`,
    );
  }
  if (!response.ok || json.error) {
    const hint = response.status === 403 || json.code === 119
      ? ' (master key IP blocked? use server script run-finance-integrity-monitor.sh on iobox)'
      : '';
    throw new Error(`Parse function call failed (${response.status})${hint}: ${JSON.stringify(json)}`);
  }

  const result = json.result || {};
  const overall = String(result.overall || 'unknown');
  const issues = Array.isArray(result.issues) ? result.issues : [];
  const checks = Array.isArray(result.checks) ? result.checks : [];

  emitOutput('overall', overall);
  emitOutput('issue_count', issues.length);
  emitOutput('check_count', checks.length);
  emitOutput('issues', issues.join(','));

  console.log(`overall=${overall}`);
  console.log(`issue_count=${issues.length}`);
  const requiredChecks = [
    'finance_prevention_indexes',
    'paired_sell_investor_chain',
    'settlement_consistency',
  ];
  for (const check of checks) {
    console.log(`check_${check.id}=${check.overall || 'unknown'}`);
  }
  for (const requiredId of requiredChecks) {
    const found = checks.find((c) => c.id === requiredId);
    if (!found || found.overall !== 'healthy') {
      console.log(`required_check_${requiredId}=${found?.overall || 'missing'}`);
      if (process.exitCode !== 1) process.exitCode = 1;
    }
  }
  if (issues.length > 0) {
    console.log(`issues=${issues.join(',')}`);
  }

  if (overall !== 'healthy') {
    process.exitCode = 1;
  }

  if (process.exitCode === 1) {
    console.error(
      'finance_integrity_monitor_failed: see check_* lines above. '
      + 'GitHub-hosted runners cannot reach private LAN Parse — use run-finance-integrity-monitor.sh on iobox.',
    );
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
