#!/usr/bin/env node
'use strict';

/**
 * CI monitor: MongoDB text/prefix indexes + adminSearchBlob samples (getAdminListSearchHealth).
 *
 * Required env (same secrets as return-percentage / mirror monitors):
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
  fs.appendFileSync(outputPath, `${name}=${value}\n`);
}

function collectionSummary(label, c) {
  if (!c || !c.ok) return `${label}: error`;
  const text = c.hasTextOnBlob ? 'text:yes' : 'text:no';
  const prefix = c.hasPrefixOnBlob ? 'prefix:yes' : 'prefix:no';
  return `${label}(${text},${prefix})`;
}

async function main() {
  const parseBase = normalizeParseBase(process.env.PARSE_SERVER_URL);
  const appId = process.env.PARSE_APP_ID;
  const masterKey = process.env.PARSE_MASTER_KEY;

  if (!parseBase || !appId || !masterKey) {
    throw new Error('Missing required env vars: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY');
  }

  const endpoint = `${parseBase}/functions/getAdminListSearchHealth`;
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
  const healthy = Boolean(result.healthy);
  const investment = result.investment || {};
  const trade = result.trade || {};
  const samples = result.samples || {};
  const repairHint = result.repairHint || '';
  const runAt = new Date().toISOString();

  emitOutput('healthy', healthy ? 'true' : 'false');
  emitOutput('investment_summary', collectionSummary('Investment', investment));
  emitOutput('trade_summary', collectionSummary('Trade', trade));
  emitOutput('sample_investment_blob', samples.investmentHasBlob ? 'true' : 'false');
  emitOutput('sample_trade_blob', samples.tradeHasBlob ? 'true' : 'false');
  emitOutput('repair_hint', repairHint.replace(/\s+/g, ' ').trim());
  emitOutput('run_at', runAt);

  console.log(`run_at=${runAt}`);
  console.log(`healthy=${healthy}`);
  console.log(collectionSummary('Investment', investment));
  console.log(collectionSummary('Trade', trade));
  console.log(`sample_investment_blob=${Boolean(samples.investmentHasBlob)}`);
  console.log(`sample_trade_blob=${Boolean(samples.tradeHasBlob)}`);
  if (repairHint) console.log(`repair_hint=${repairHint}`);

  if (!healthy) {
    throw new Error(
      `Admin list search unhealthy. ${repairHint || 'Run ensureAdminListSearchIndexes + backfill-trade-summary-flags.sh'}`,
    );
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
