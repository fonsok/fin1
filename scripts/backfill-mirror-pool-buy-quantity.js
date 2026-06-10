#!/usr/bin/env node
'use strict';

/**
 * Repair MIRROR_POOL buy qty/buyAmount drift from PoolTradeParticipation.buySnapshot sums.
 *
 * Env: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
 * Optional: DRY_RUN=0 (default 1), LIMIT=50, MIRROR_TRADE_ID=..., PAIR_EXECUTION_ID=...
 */

const Parse = require('parse/node');
const {
  repairMirrorPoolBuyQuantityBatch,
} = require('../backend/parse-server/cloud/services/poolMirrorActivation/repairMirrorPoolBuyQuantity');

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

async function main() {
  Parse.initialize(requireEnv('PARSE_APP_ID'), '', requireEnv('PARSE_MASTER_KEY'));
  Parse.serverURL = requireEnv('PARSE_SERVER_URL');

  const dryRun = process.env.DRY_RUN !== '0';
  const limit = Number(process.env.LIMIT || 50);
  const mirrorTradeId = String(process.env.MIRROR_TRADE_ID || process.env.POOL_TRADE_ID || '').trim() || null;
  const pairExecutionId = String(process.env.PAIR_EXECUTION_ID || '').trim() || null;
  const resyncSellFromTrader = process.env.RESYNC_SELL !== '0';

  const report = await repairMirrorPoolBuyQuantityBatch({
    dryRun,
    limit,
    mirrorTradeId,
    pairExecutionId,
    resyncSellFromTrader,
  });

  console.log(JSON.stringify(report, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
