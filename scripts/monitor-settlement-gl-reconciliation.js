#!/usr/bin/env node
'use strict';

/**
 * Monitor: AccountStatement ↔ AppLedger settlement GL reconciliation.
 *
 * Required env: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
 * Optional: SETTLEMENT_GL_RECON_MAX_VIOLATIONS (default 0)
 */

const maxViolations = Number(process.env.SETTLEMENT_GL_RECON_MAX_VIOLATIONS ?? 0);

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

  const response = await fetch(`${parseBase}/functions/getSettlementGLReconciliationStatus`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Parse-Application-Id': appId,
      'X-Parse-Master-Key': masterKey,
    },
    body: JSON.stringify({ limit: 50 }),
  });

  const json = await response.json();
  if (!response.ok || json.error) {
    throw new Error(`Parse function call failed (${response.status}): ${JSON.stringify(json)}`);
  }

  const result = json.result || {};
  const overall = String(result.overall || 'unknown');
  const violationCount = Number(result.violationCount ?? -1);
  const checkedTrades = Number(result.checkedTrades ?? 0);
  const checkedAt = result.checkedAt || new Date().toISOString();

  console.log(`checked_at=${checkedAt}`);
  console.log(`overall=${overall}`);
  console.log(`checked_trades=${checkedTrades}`);
  console.log(`violation_count=${violationCount}`);

  if (violationCount > maxViolations) {
    throw new Error(
      `Settlement GL reconciliation breach: violation_count=${violationCount} > max=${maxViolations}`,
    );
  }

  if (overall !== 'healthy' && overall !== 'unknown') {
    throw new Error(`Settlement GL reconciliation overall=${overall}`);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
