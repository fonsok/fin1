'use strict';

const { normalizeStatus } = require('../../utils/pairedOrderStatusCoupling');
const { getPoolActivationLimiterStats } = require('../../utils/poolActivationLimiter');
const { getPairedBuySettlementQueueStats } = require('../../utils/pairedBuySettlementQueue');

/**
 * Admin health: all Order legs sharing pairExecutionId must have identical status.
 */
async function handleGetPairedOrderStatusIntegrityStatus() {
  const orders = await new Parse.Query('Order')
    .exists('pairExecutionId')
    .descending('createdAt')
    .limit(2000)
    .find({ useMasterKey: true });

  const byPair = new Map();
  for (const order of orders) {
    const pairId = String(order.get('pairExecutionId') || '').trim();
    if (!pairId) continue;
    if (!byPair.has(pairId)) byPair.set(pairId, []);
    byPair.get(pairId).push(order);
  }

  const violations = [];
  for (const [pairExecutionId, legs] of byPair.entries()) {
    if (legs.length < 2) continue;
    const statuses = legs.map((o) => normalizeStatus(o.get('status')));
    const unique = [...new Set(statuses)];
    if (unique.length > 1) {
      violations.push({
        type: 'paired_order_status_drift',
        pairExecutionId,
        statuses: legs.map((o) => ({
          orderId: o.id,
          legType: o.get('legType') || null,
          status: o.get('status') || null,
        })),
      });
    }
  }

  return {
    overall: violations.length === 0 ? 'healthy' : 'degraded',
    checkedPairs: byPair.size,
    violationCount: violations.length,
    poolActivationLimiter: await getPoolActivationLimiterStats(),
    pairedBuySettlementQueue: await getPairedBuySettlementQueueStats(),
    violations: violations.slice(0, 50),
    message: violations.length === 0
      ? 'Paired order leg statuses are aligned'
      : `${violations.length} paired order status drift violation(s)`,
  };
}

module.exports = {
  handleGetPairedOrderStatusIntegrityStatus,
};
