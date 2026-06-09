#!/usr/bin/env node
'use strict';

/**
 * Monitor: Trader↔Pool Bid/Ask-only contract (ADR-016 Phase 4.1).
 *
 * Required env: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
 * Optional: TRADER_POOL_BID_ASK_MAX_VIOLATIONS (default 0)
 */

const maxViolations = Number(process.env.TRADER_POOL_BID_ASK_MAX_VIOLATIONS ?? 0);

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

  const response = await fetch(`${parseBase}/functions/getTraderPoolBidAskContractStatus`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
    },
    body: JSON.stringify({ limit: 100 }),
  });

  const json = await response.json();
  if (!response.ok || json.error) {
    throw new Error(`Parse function call failed (${response.status}): ${JSON.stringify(json)}`);
  }

  const result = json.result || {};
  const overall = String(result.overall || 'unknown');
  const violationCount = Number(result.violationCount ?? -1);
  const checkedPairs = Number(result.checkedPairs ?? 0);
  const checkedAt = result.checkedAt || new Date().toISOString();

  console.log(`checked_at=${checkedAt}`);
  console.log(`overall=${overall}`);
  console.log(`checked_pairs=${checkedPairs}`);
  console.log(`violation_count=${violationCount}`);

  if (violationCount > maxViolations) {
    throw new Error(
      `Trader↔Pool Bid/Ask contract breach: violation_count=${violationCount} > max=${maxViolations}`,
    );
  }

  if (overall !== 'healthy' && overall !== 'unknown') {
    throw new Error(`Trader↔Pool Bid/Ask contract overall=${overall}`);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
