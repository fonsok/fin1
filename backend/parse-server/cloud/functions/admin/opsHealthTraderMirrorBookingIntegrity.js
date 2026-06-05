'use strict';

const {
  TRADER_CUSTOMER_ENTRY_TYPE_SET,
} = require('../../services/poolMirrorActivation/traderCustomerBookingPolicy');

/**
 * Admin health: trader-facing AccountStatement rows must not reference MIRROR_POOL trades.
 */
async function handleGetTraderMirrorBookingIntegrityStatus() {
  const mirrorTrades = await new Parse.Query('Trade')
    .equalTo('buyLegType', 'MIRROR_POOL')
    .descending('createdAt')
    .limit(500)
    .find({ useMasterKey: true });

  const mirrorTradeIds = mirrorTrades.map((t) => t.id);
  if (mirrorTradeIds.length === 0) {
    return {
      overall: 'healthy',
      checkedMirrorTrades: 0,
      phantomTraderStatementCount: 0,
      violations: [],
      message: 'No MIRROR_POOL trades to check',
    };
  }

  const traderIdByMirrorTradeId = new Map(
    mirrorTrades.map((t) => [t.id, String(t.get('traderId') || '').trim()]),
  );

  const phantomRows = await new Parse.Query('AccountStatement')
    .containedIn('tradeId', mirrorTradeIds)
    .containedIn('entryType', [...TRADER_CUSTOMER_ENTRY_TYPE_SET])
    .equalTo('source', 'backend')
    .descending('createdAt')
    .limit(200)
    .find({ useMasterKey: true });

  const violations = [];
  for (const row of phantomRows) {
    const tradeId = String(row.get('tradeId') || '');
    const rowUserId = String(row.get('userId') || '').trim();
    const traderId = traderIdByMirrorTradeId.get(tradeId) || '';
    if (traderId && rowUserId && rowUserId !== traderId) {
      continue;
    }
    violations.push({
      type: 'trader_statement_on_mirror_pool_trade',
      accountStatementId: row.id,
      tradeId,
      entryType: row.get('entryType') || null,
      amount: row.get('amount') ?? null,
      userId: rowUserId || null,
      referenceDocumentNumber: row.get('referenceDocumentNumber') || null,
      createdAt: row.get('createdAt') || null,
    });
  }

  return {
    overall: violations.length === 0 ? 'healthy' : 'degraded',
    checkedMirrorTrades: mirrorTradeIds.length,
    phantomTraderStatementCount: violations.length,
    violations: violations.slice(0, 50),
    message: violations.length === 0
      ? 'No trader customer bookings on MIRROR_POOL trades'
      : `${violations.length} trader customer booking(s) on MIRROR_POOL trade(s)`,
  };
}

module.exports = {
  handleGetTraderMirrorBookingIntegrityStatus,
};
