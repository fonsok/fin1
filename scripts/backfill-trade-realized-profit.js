#!/usr/bin/env node
'use strict';

/**
 * Backfill Trade.grossProfit / calculatedProfit from cumulative sellOrders snapshots.
 * Fixes rows stuck after first partial sell (e.g. firstSellTotal - fullBuy = -660).
 *
 * Env: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
 */

const Parse = require('parse/node');
const { resolveTradeRealizedGrossProfit } = require('../backend/parse-server/cloud/triggers/tradeRealizedGrossProfit');

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

async function main() {
  Parse.initialize(requireEnv('PARSE_APP_ID'), '', requireEnv('PARSE_MASTER_KEY'));
  Parse.serverURL = requireEnv('PARSE_SERVER_URL');

  const limit = Number(process.env.LIMIT || 200);
  let skip = 0;
  let updated = 0;
  let scanned = 0;

  for (;;) {
    const q = new Parse.Query('Trade');
    q.limit(limit);
    q.skip(skip);
    const batch = await q.find({ useMasterKey: true });
    if (!batch.length) break;

    for (const trade of batch) {
      scanned += 1;
      const realized = resolveTradeRealizedGrossProfit(trade);
      if (realized === null || !Number.isFinite(realized)) continue;

      const prev = Number(trade.get('calculatedProfit') ?? trade.get('grossProfit') ?? NaN);
      if (Number.isFinite(prev) && Math.abs(prev - realized) < 0.01) continue;

      trade.set('grossProfit', realized);
      trade.set('calculatedProfit', realized);
      const buyAmt = Number(trade.get('buyAmount') || trade.get('buyOrder')?.totalAmount || 0);
      if (buyAmt > 0) {
        trade.set('profitPercentage', (realized / buyAmt) * 100);
      }
      await trade.save(null, { useMasterKey: true });
      updated += 1;
      console.log(
        `updated trade #${trade.get('tradeNumber')} ${trade.id}: ${prev} -> ${realized}`,
      );
    }

    if (batch.length < limit) break;
    skip += limit;
  }

  console.log(`done: scanned=${scanned} updated=${updated}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
