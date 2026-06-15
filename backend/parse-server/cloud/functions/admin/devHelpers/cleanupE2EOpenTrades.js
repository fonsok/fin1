'use strict';

const { requireAdminRole } = require('../../../utils/permissions');

const E2E_SYMBOL_PREFIX = 'E2E-';

/**
 * Dev-only: remove orphan open trades created by E2E scripts (symbol prefix E2E-).
 * Does not touch completed trades or production WKNs.
 */
async function handleDevCleanupE2EOpenTrades(request) {
  if (!request.master) {
    requireAdminRole(request);
  }

  const traderId = String(request.params?.traderId || '').trim();
  const apply = request.params?.dryRun === false || request.params?.dryRun === 'false';

  const query = new Parse.Query('Trade');
  query.startsWith('symbol', E2E_SYMBOL_PREFIX);
  query.containedIn('status', ['active', 'partial', 'pending']);
  if (traderId) {
    query.equalTo('traderId', traderId);
  }
  query.limit(100);
  const trades = await query.find({ useMasterKey: true });

  const results = [];
  for (const trade of trades) {
    const row = {
      tradeId: trade.id,
      tradeNumber: trade.get('tradeNumber'),
      symbol: trade.get('symbol'),
      traderId: trade.get('traderId'),
      quantity: trade.get('quantity'),
      remainingQuantity: trade.get('remainingQuantity'),
      status: trade.get('status'),
    };
    if (!apply) {
      results.push({ ...row, action: 'would_delete' });
      continue;
    }

    const pairExecutionId = String(trade.get('pairExecutionId') || '').trim();
    const orderIds = [];
    if (pairExecutionId) {
      const orders = await new Parse.Query('Order')
        .equalTo('pairExecutionId', pairExecutionId)
        .limit(20)
        .find({ useMasterKey: true });
      orderIds.push(...orders.map((o) => o.id));
      if (orders.length) {
        await Parse.Object.destroyAll(orders, { useMasterKey: true });
      }
    }

    const buyOrderId = String(trade.get('buyOrderId') || '').trim();
    if (buyOrderId && !orderIds.includes(buyOrderId)) {
      try {
        const buyOrder = await new Parse.Query('Order').get(buyOrderId, { useMasterKey: true });
        await buyOrder.destroy({ useMasterKey: true });
        orderIds.push(buyOrderId);
      } catch (_e) {
        // already removed with pair cluster
      }
    }

    await trade.destroy({ useMasterKey: true });
    results.push({ ...row, action: 'deleted', orderIds });
  }

  return {
    dryRun: !apply,
    symbolPrefix: E2E_SYMBOL_PREFIX,
    traderId: traderId || null,
    matched: trades.length,
    results,
    ranAt: new Date().toISOString(),
  };
}

function registerDevCleanupE2EOpenTrades() {
  Parse.Cloud.define('cleanupE2EOpenTrades', async (request) => handleDevCleanupE2EOpenTrades(request));
}

module.exports = {
  handleDevCleanupE2EOpenTrades,
  registerDevCleanupE2EOpenTrades,
};
