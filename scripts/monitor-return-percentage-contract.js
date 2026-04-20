#!/usr/bin/env node
'use strict';

/**
 * CI/ops monitor for the server-owned return% contract.
 *
 * Required env:
 * - PARSE_SERVER_URL (e.g. https://example.com/parse or https://example.com)
 * - PARSE_APP_ID
 * - PARSE_MASTER_KEY
 *
 * Optional env:
 * - MONITOR_THRESHOLD (default: 0)
 * - MONITOR_SAMPLE_LIMIT (default: 5)
 */

const threshold = Number(process.env.MONITOR_THRESHOLD || 0);
const sampleLimit = Number(process.env.MONITOR_SAMPLE_LIMIT || 5);

function normalizeParseBase(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.endsWith('/parse') ? trimmed : `${trimmed}/parse`;
}

function emitOutput(name, value) {
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;
  const fs = require('fs');
  fs.appendFileSync(outputPath, `${name}=${value}\n`);
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL);
  const appId = process.env.PARSE_APP_ID;
  const masterKey = process.env.PARSE_MASTER_KEY;

  if (!parseBase || !appId || !masterKey) {
    throw new Error('Missing required env vars: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY');
  }

  const endpoint = `${parseBase}/functions/auditCollectionBillReturnPercentage`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
    },
    body: JSON.stringify({ limit: sampleLimit }),
  });

  const json = await response.json();
  if (!response.ok || json.error) {
    throw new Error(`Parse function call failed (${response.status}): ${JSON.stringify(json)}`);
  }

  const result = json.result || {};
  const missingCount = Number(result.missingReturnPercentageCount || 0);
  const totalActive = Number(result.totalActiveCollectionBills || 0);
  const healthy = Boolean(result.healthy);
  const checkedAt = result.checkedAt || new Date().toISOString();

  emitOutput('missing_count', missingCount);
  emitOutput('total_active', totalActive);
  emitOutput('healthy', healthy);
  emitOutput('checked_at', checkedAt);

  console.log(`checked_at=${checkedAt}`);
  console.log(`total_active_collection_bills=${totalActive}`);
  console.log(`missing_return_percentage_count=${missingCount}`);
  console.log(`healthy=${healthy}`);
  console.log(`threshold=${threshold}`);

  if (missingCount > threshold) {
    throw new Error(`Return% contract breach: missing_count=${missingCount} > threshold=${threshold}`);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
