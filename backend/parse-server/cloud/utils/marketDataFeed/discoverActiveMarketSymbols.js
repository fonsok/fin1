'use strict';

const DEFAULT_LOOKBACK_DAYS = 30;
const DEFAULT_SYMBOL_LIMIT = 50;
const MAX_SCAN_ROWS = 1000;

/**
 * Distinct WKN/symbols from recent Trade + Order rows (trader activity).
 */
async function discoverActiveMarketSymbols({
  lookbackDays = DEFAULT_LOOKBACK_DAYS,
  limit = DEFAULT_SYMBOL_LIMIT,
} = {}) {
  const since = new Date(Date.now() - lookbackDays * 24 * 60 * 60 * 1000);
  const symbols = new Set();

  for (const className of ['Trade', 'Order']) {
    const query = new Parse.Query(className);
    query.greaterThan('createdAt', since);
    query.exists('symbol');
    query.limit(MAX_SCAN_ROWS);
    const rows = await query.find({ useMasterKey: true });
    for (const row of rows) {
      const key = String(row.get('symbol') || '').trim();
      if (key) {
        symbols.add(key);
      }
    }
  }

  return Array.from(symbols).sort().slice(0, Math.max(1, limit));
}

module.exports = {
  discoverActiveMarketSymbols,
  DEFAULT_LOOKBACK_DAYS,
  DEFAULT_SYMBOL_LIMIT,
};
