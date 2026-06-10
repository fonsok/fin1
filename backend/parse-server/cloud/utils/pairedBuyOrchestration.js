// ============================================================================
// Paired buy server-side settlement (Variant A)
// After executePairedBuy persists Order legs, transitions each buy leg to `executed`
// so order.js afterSave runs: Trade + Invoice; pool allocation only on MIRROR_POOL leg.
// Idempotent via PairedExecution.effectsApplied and per-order status checks.
// ============================================================================

'use strict';

const { calculateOrderFees } = require('./helpers');
const { pairedStatusBatchContext } = require('./pairedOrderShared');
const { allocateTradeToInvestmentPools } = require('../triggers/orderPoolAllocation');
const {
  advancePairedOrderLegsStatus,
  statusRank,
  pairedLegsCanonicalStatus,
} = require('./pairedOrderStatusCoupling');
const { isMirrorPoolOrderLeg } = require('../services/poolMirrorActivation/poolActivationPolicy');
const {
  applyResolvedMirrorPoolBuyQuantityToOrder,
} = require('../services/poolMirrorActivation/resolveMirrorPoolBuyQuantity');
const { loadConfig } = require('./configHelper/index.js');

const BUY_EXECUTABLE_STATUSES = new Set([
  'pending', 'submitted', 'suspended', 'confirmed', 'completed',
]);

function sortPairedBuyLegs(orders) {
  return [...orders].sort((a, b) => {
    const L = (a.get('legType') || '').toUpperCase();
    const R = (b.get('legType') || '').toUpperCase();
    if (L === 'TRADER' && R === 'MIRROR_POOL') return -1;
    if (L === 'MIRROR_POOL' && R === 'TRADER') return 1;
    return 0;
  });
}

/**
 * @param {string} pairExecutionId
 * @returns {Promise<{ ok: boolean, buyLegs: Parse.Object[], mirrorLeg: Parse.Object|null, issues: string[] }>}
 */
async function verifyPairedBuySettlement(pairExecutionId) {
  const orders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairExecutionId)
    .find({ useMasterKey: true });

  const buyLegs = orders.filter((o) => (o.get('side') || '') === 'buy');
  const mirrorLeg = buyLegs.find((o) => String(o.get('legType') || '').toUpperCase() === 'MIRROR_POOL') || null;
  const issues = [];

  for (const leg of buyLegs) {
    const legType = String(leg.get('legType') || 'unknown');
    const status = String(leg.get('status') || '');
    if (status !== 'executed') {
      issues.push(`${legType}_order_not_executed:${status}`);
    }
    if (!String(leg.get('tradeId') || '').trim()) {
      issues.push(`${legType}_order_missing_trade`);
    }
  }

  const mirrorQty = Number(mirrorLeg?.get('quantity') || 0);
  if (mirrorLeg && mirrorQty > 0) {
    const mirrorTrade = await new Parse.Query('Trade')
      .equalTo('buyOrderId', mirrorLeg.id)
      .first({ useMasterKey: true });
    if (!mirrorTrade) {
      issues.push('mirror_trade_missing');
    } else {
      const participation = await new Parse.Query('PoolTradeParticipation')
        .equalTo('tradeId', mirrorTrade.id)
        .first({ useMasterKey: true });
      if (!participation) {
        issues.push('mirror_pool_not_activated');
      }
    }
  }

  return {
    ok: issues.length === 0,
    buyLegs,
    mirrorLeg,
    issues,
  };
}

/**
 * @param {string} pairExecutionId — PairedExecution.objectId
 */
async function finalizePairedBuyAfterCommit(pairExecutionId) {
  const PairedExecution = Parse.Object.extend('PairedExecution');
  let execution;
  try {
    execution = await new Parse.Query(PairedExecution).get(pairExecutionId, { useMasterKey: true });
  } catch (e) {
    console.error('finalizePairedBuyAfterCommit: PairedExecution not found', pairExecutionId, e.message);
    return;
  }

  if (execution.get('effectsApplied') === true) {
    const check = await verifyPairedBuySettlement(pairExecutionId);
    if (check.ok) {
      return;
    }
    console.warn(
      `finalizePairedBuyAfterCommit: effectsApplied but incomplete pair ${pairExecutionId}: ${check.issues.join(', ')} — repairing`,
    );
    execution.set('effectsApplied', false);
    await execution.save(null, { useMasterKey: true });
  }

  const traderId = String(execution.get('traderId') || '').trim();

  const orders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairExecutionId)
    .ascending('createdAt')
    .find({ useMasterKey: true });

  const buyLegs = orders.filter((o) => (o.get('side') || '') === 'buy');
  const currentStatus = pairedLegsCanonicalStatus(buyLegs);
  if (currentStatus && statusRank(currentStatus) < statusRank('suspended') && traderId) {
    try {
      await advancePairedOrderLegsStatus(pairExecutionId, traderId, 'suspended');
    } catch (err) {
      console.warn(
        `finalizePairedBuyAfterCommit: pre-suspended advance failed for ${pairExecutionId}:`,
        err.message || err,
      );
    }
  }

  const refreshedOrders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairExecutionId)
    .ascending('createdAt')
    .find({ useMasterKey: true });
  const sorted = sortPairedBuyLegs(refreshedOrders);

  // Sequential saves (TRADER before MIRROR_POOL): avoid saveAll + nested order.save in afterSave
  // skipping mirror leg trade creation / pool activation.
  const config = await loadConfig();
  const feeConfig = config.financial || {};

  for (const order of sorted) {
    if ((order.get('side') || '') !== 'buy') continue;

    if (isMirrorPoolOrderLeg(order)) {
      const applied = await applyResolvedMirrorPoolBuyQuantityToOrder(order, { feeConfig });
      if (!applied.ok) {
        console.warn(
          `finalizePairedBuyAfterCommit: mirror pool qty resolve failed pair ${pairExecutionId}: ${applied.reason}`,
        );
        continue;
      }
    }

    const prepared = preparePairedBuyLegExecutedFields(order);
    if (!prepared) continue;
    await prepared.save(null, { useMasterKey: true, context: pairedStatusBatchContext() });
  }

  await ensureMirrorPoolActivationForPair(pairExecutionId);

  const verification = await verifyPairedBuySettlement(pairExecutionId);
  if (!verification.ok) {
    console.error(
      `finalizePairedBuyAfterCommit: settlement incomplete for pair ${pairExecutionId}: ${verification.issues.join(', ')}`,
    );
    return;
  }

  execution.set('effectsApplied', true);
  execution.set('effectsAppliedAt', new Date().toISOString());
  await execution.save(null, { useMasterKey: true });
}

/**
 * Idempotent pool activation for the mirror leg (repair path after sequential finalize).
 */
async function ensureMirrorPoolActivationForPair(pairExecutionId) {
  const orders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairExecutionId)
    .find({ useMasterKey: true });

  const mirrorLeg = orders.find(
    (o) => (o.get('side') || '') === 'buy'
      && String(o.get('legType') || '').toUpperCase() === 'MIRROR_POOL',
  );
  if (!mirrorLeg) return;

  const mirrorQty = Number(mirrorLeg.get('quantity') || 0);
  if (mirrorQty <= 0) return;

  const tradeId = String(mirrorLeg.get('tradeId') || '').trim();
  let mirrorTrade = null;
  if (tradeId) {
    try {
      mirrorTrade = await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
    } catch (_) {
      mirrorTrade = null;
    }
  }
  if (!mirrorTrade) {
    mirrorTrade = await new Parse.Query('Trade')
      .equalTo('buyOrderId', mirrorLeg.id)
      .first({ useMasterKey: true });
  }
  if (!mirrorTrade) return;

  if (!String(mirrorTrade.get('buyLegType') || '').trim()) {
    mirrorTrade.set('buyLegType', 'MIRROR_POOL');
    const pairId = String(mirrorLeg.get('pairExecutionId') || '').trim();
    if (pairId) {
      mirrorTrade.set('pairExecutionId', pairId);
    }
    await mirrorTrade.save(null, { useMasterKey: true });
  }

  await allocateTradeToInvestmentPools(mirrorTrade, mirrorLeg);
}

/**
 * @param {Parse.Object} order
 * @returns {Parse.Object|null} order if it should be saved, null if already settled
 */
function preparePairedBuyLegExecutedFields(order) {
  if ((order.get('side') || '') !== 'buy') return null;

  const cur = String(order.get('status') || '').toLowerCase().trim();
  if (cur === 'executed' && String(order.get('tradeId') || '').trim()) {
    return null;
  }
  if (cur === 'cancelled' || cur === 'failed') {
    return null;
  }
  if (!BUY_EXECUTABLE_STATUSES.has(cur) && cur !== 'executed') {
    return null;
  }

  const qty = Number(order.get('quantity') || 0);
  const price = Number(order.get('price') || 0);
  let grossAmount;
  if (isMirrorPoolOrderLeg(order)) {
    grossAmount = Number(order.get('grossAmount') || order.get('totalAmount') || 0);
    if (!(grossAmount > 0) && qty > 0 && price > 0) {
      grossAmount = qty * price;
    }
  } else {
    grossAmount = qty * price;
  }
  const fees = calculateOrderFees(grossAmount, false);
  const netAmount = grossAmount + fees.totalFees;

  order.set('grossAmount', grossAmount);
  order.set('totalFees', fees.totalFees);
  order.set('netAmount', netAmount);
  order.set('executedQuantity', qty);
  order.set('remainingQuantity', 0);
  order.set('status', 'executed');
  if (!order.get('executedAt')) {
    order.set('executedAt', new Date());
  }

  return order;
}

/**
 * Pending → executed with fee fields filled; triggers Parse afterSave trade + invoice logic.
 */
async function transitionPairedBuyLegToExecuted(orderObjectId) {
  const order = await new Parse.Query('Order').get(orderObjectId, { useMasterKey: true });
  const prepared = preparePairedBuyLegExecutedFields(order);
  if (!prepared) return;
  await prepared.save(null, { useMasterKey: true, context: pairedStatusBatchContext() });
}

module.exports = {
  finalizePairedBuyAfterCommit,
  transitionPairedBuyLegToExecuted,
  preparePairedBuyLegExecutedFields,
  verifyPairedBuySettlement,
  ensureMirrorPoolActivationForPair,
};
