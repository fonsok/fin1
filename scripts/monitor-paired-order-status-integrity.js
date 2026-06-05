#!/usr/bin/env node
'use strict';

/**
 * CI monitor: paired TRADER + MIRROR_POOL order leg status drift (getPairedOrderStatusIntegrityStatus).
 *
 * Required env (same secrets as other FIN1 Parse monitors):
 * - PARSE_SERVER_URL
 * - PARSE_APP_ID
 * - PARSE_MASTER_KEY
 *
 * Optional:
 * - PAIRED_STATUS_MAX_VIOLATIONS (default: 0)
 */

const maxViolations = Number(process.env.PAIRED_STATUS_MAX_VIOLATIONS ?? 0);

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

  const endpoint = `${parseBase}/functions/getPairedOrderStatusIntegrityStatus`;
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
  const violationCount = Number(result.violationCount ?? 0);
  const checkedPairs = Number(result.checkedPairs ?? 0);
  const limiter = result.poolActivationLimiter || {};
  const settlementQueue = result.pairedBuySettlementQueue || {};
  const runAt = new Date().toISOString();

  emitOutput('overall', overall);
  emitOutput('violation_count', violationCount);
  emitOutput('checked_pairs', checkedPairs);
  emitOutput('pool_active', limiter.active ?? 'n/a');
  emitOutput('pool_queued', limiter.queued ?? 'n/a');
  emitOutput('pool_max_concurrent', limiter.maxConcurrent ?? 'n/a');
  emitOutput('settlement_queue_mode', settlementQueue.mode ?? 'n/a');
  emitOutput('finalize_max_concurrent', settlementQueue.finalizeMaxConcurrent ?? 'n/a');
  emitOutput('run_at', runAt);

  console.log(`run_at=${runAt}`);
  console.log(`overall=${overall}`);
  console.log(`checked_pairs=${checkedPairs}`);
  console.log(`violation_count=${violationCount}`);
  console.log(`pool_activation_limiter=${JSON.stringify(limiter)}`);
  console.log(`paired_buy_settlement_queue=${JSON.stringify(settlementQueue)}`);

  if (Array.isArray(result.violations) && result.violations.length > 0) {
    console.log('violations_sample=' + JSON.stringify(result.violations.slice(0, 5)));
  }

  if (overall !== 'healthy' || violationCount > maxViolations) {
    throw new Error(
      `Paired order status integrity failed: overall=${overall}, violations=${violationCount}, max=${maxViolations}`,
    );
  }

  console.log('Paired order status integrity monitor: OK');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
