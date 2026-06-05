#!/usr/bin/env node
'use strict';

/**
 * CI monitor: mirror-basis drift snapshot (`OpsHealthSnapshot` / getMirrorBasisDriftStatus).
 *
 * Required env (same as return-percentage monitor):
 * - PARSE_SERVER_URL
 * - PARSE_APP_ID
 * - PARSE_MASTER_KEY
 *
 * Optional:
 * - MIRROR_DRIFT_MAX_DRIFTED (default: 0)
 * - MIRROR_DRIFT_MAX_AGE_SECONDS (default: 691200 = 8 days)
 */

const maxDrifted = Number(process.env.MIRROR_DRIFT_MAX_DRIFTED ?? 0);
const maxAgeSeconds = Number(process.env.MIRROR_DRIFT_MAX_AGE_SECONDS ?? 691200);

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

  const endpoint = `${parseBase}/functions/getMirrorBasisDriftStatus`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
    },
    body: JSON.stringify({}),
  });

  const json = await response.json();
  if (!response.ok || json.error) {
    throw new Error(`Parse function call failed (${response.status}): ${JSON.stringify(json)}`);
  }

  const result = json.result || {};
  const overall = String(result.overall || 'unknown');
  const drifted = Number(result.driftedDocuments ?? -1);
  const checked = Number(result.checkedDocuments ?? 0);
  const ageSeconds = result.ageSeconds == null ? null : Number(result.ageSeconds);
  const hasSnapshot = Boolean(result.hasSnapshot);
  const runAt = result.runAt || new Date().toISOString();

  emitOutput('overall', overall);
  emitOutput('drifted_documents', drifted);
  emitOutput('checked_documents', checked);
  emitOutput('age_seconds', ageSeconds ?? '');
  emitOutput('has_snapshot', hasSnapshot);
  emitOutput('run_at', runAt);

  console.log(`run_at=${runAt}`);
  console.log(`has_snapshot=${hasSnapshot}`);
  console.log(`overall=${overall}`);
  console.log(`checked_documents=${checked}`);
  console.log(`drifted_documents=${drifted}`);
  console.log(`age_seconds=${ageSeconds ?? 'n/a'}`);

  if (!hasSnapshot) {
    throw new Error('Mirror-basis drift: no OpsHealthSnapshot yet (cron not run?)');
  }

  if (ageSeconds != null && ageSeconds > maxAgeSeconds) {
    throw new Error(`Mirror-basis drift snapshot stale: age_seconds=${ageSeconds} > max=${maxAgeSeconds}`);
  }

  if (drifted > maxDrifted) {
    throw new Error(`Mirror-basis drift breach: drifted_documents=${drifted} > max=${maxDrifted}`);
  }

  if (overall !== 'healthy' && overall !== 'unknown') {
    throw new Error(`Mirror-basis drift overall=${overall}: ${result.reason || 'see snapshot'}`);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
