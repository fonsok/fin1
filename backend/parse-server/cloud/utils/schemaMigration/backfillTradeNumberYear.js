'use strict';

const { getTradeNumberCalendarYear } = require('../tradeNumberAllocation');

/**
 * Backfill Trade.tradeNumberYear from createdAt (Europe/Berlin calendar year).
 * @returns {Promise<Record<string, unknown>>}
 */
async function backfillTradeNumberYear() {
  const Trade = Parse.Object.extend('Trade');
  const batchSize = 200;
  let processed = 0;
  let updated = 0;
  let hasMore = true;

  while (hasMore) {
    const q = new Parse.Query(Trade);
    q.doesNotExist('tradeNumberYear');
    q.limit(batchSize);
    const rows = await q.find({ useMasterKey: true });
    if (rows.length === 0) {
      hasMore = false;
      break;
    }

    for (const trade of rows) {
      processed += 1;
      const createdAt = trade.get('createdAt') || trade.createdAt;
      const year = getTradeNumberCalendarYear(createdAt);
      trade.set('tradeNumberYear', year);
    }

    await Parse.Object.saveAll(rows, { useMasterKey: true });
    updated += rows.length;
    hasMore = rows.length === batchSize;
  }

  return { ok: true, processed, updated };
}

module.exports = {
  backfillTradeNumberYear,
};
