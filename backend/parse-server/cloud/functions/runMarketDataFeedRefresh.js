'use strict';

const { requireAdminRole } = require('../utils/permissions');
const { refreshMarketDataQuotes } = require('../utils/marketDataFeed/refreshMarketDataQuotes');

/**
 * Manual/ops trigger for mock market-data feed (admin or master).
 * Used by smokes and iobox ops; periodic refresh runs in main.js worker.
 */
async function handleRunMarketDataFeedRefresh(request) {
  if (!request.master) {
    requireAdminRole(request);
  }

  const { symbols } = request.params || {};
  const symbolList = Array.isArray(symbols)
    ? symbols.map((s) => String(s || '').trim()).filter(Boolean)
    : null;

  return refreshMarketDataQuotes({
    symbols: symbolList && symbolList.length > 0 ? symbolList : null,
  });
}

module.exports = {
  handleRunMarketDataFeedRefresh,
};
