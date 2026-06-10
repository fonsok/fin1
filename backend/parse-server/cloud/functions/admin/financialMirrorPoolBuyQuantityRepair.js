'use strict';

const { audit } = require('../../utils/structuredLogger');
const {
  repairMirrorPoolBuyQuantityBatch,
} = require('../../services/poolMirrorActivation/repairMirrorPoolBuyQuantity');

/**
 * Admin repair: align MIRROR_POOL Trade.quantity / buyAmount / buyOrder (+ Order row)
 * from PoolTradeParticipation.buySnapshot sums (pre-compute-first drift).
 *
 * @param {import('parse/node').Cloud.FunctionRequest} request
 */
async function handleRepairMirrorPoolBuyQuantity(request) {
  const params = request.params || {};
  const dryRun = params.dryRun !== false;
  const limit = params.limit;
  const mirrorTradeId = params.mirrorTradeId || params.poolTradeId || null;
  const pairExecutionId = params.pairExecutionId || null;
  const resyncSellFromTrader = params.resyncSellFromTrader !== false;

  const initiatedByUserId = request.user?.id || null;
  audit.info('poolMirror.admin.repairBuyQuantity.request', {
    dryRun,
    limit,
    mirrorTradeId,
    pairExecutionId,
    resyncSellFromTrader,
    initiatedByUserId,
  });

  const report = await repairMirrorPoolBuyQuantityBatch({
    dryRun,
    limit,
    mirrorTradeId,
    pairExecutionId,
    resyncSellFromTrader,
  });

  audit.info('poolMirror.admin.repairBuyQuantity.done', {
    dryRun,
    scanned: report.scanned,
    driftCount: report.driftCount,
    repairedCount: report.repairedCount,
    initiatedByUserId,
  });

  return report;
}

module.exports = { handleRepairMirrorPoolBuyQuantity };
