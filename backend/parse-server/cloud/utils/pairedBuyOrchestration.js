// ============================================================================
// Paired buy server-side settlement (Variant A)
// After executePairedBuy persists Order legs, transitions each buy leg to `executed`
// so order.js afterSave runs: Trade + Invoice; pool allocation only on MIRROR_POOL leg.
// Idempotent via PairedExecution.effectsApplied and per-order status checks.
// ============================================================================

'use strict';

const { calculateOrderFees } = require('./helpers');

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
    return;
  }

  const orders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairExecutionId)
    .ascending('createdAt')
    .find({ useMasterKey: true });

  const sorted = [...orders].sort((a, b) => {
    const L = (a.get('legType') || '').toUpperCase();
    const R = (b.get('legType') || '').toUpperCase();
    if (L === 'TRADER' && R === 'MIRROR_POOL') return -1;
    if (L === 'MIRROR_POOL' && R === 'TRADER') return 1;
    return 0;
  });

  for (const o of sorted) {
    if ((o.get('side') || '') !== 'buy') continue;
    await transitionPairedBuyLegToExecuted(o.id);
  }

  execution.set('effectsApplied', true);
  execution.set('effectsAppliedAt', new Date().toISOString());
  await execution.save(null, { useMasterKey: true });
}

/**
 * Pending → executed with fee fields filled; triggers Parse afterSave trade + invoice logic.
 */
async function transitionPairedBuyLegToExecuted(orderObjectId) {
  const order = await new Parse.Query('Order').get(orderObjectId, { useMasterKey: true });
  if ((order.get('side') || '') !== 'buy') return;

  const cur = String(order.get('status') || '');
  if (cur === 'executed' && order.get('tradeId')) {
    return;
  }

  // Already marked executed (e.g. partial retry): do not resend duplicate transition
  if (cur === 'executed') {
    return;
  }

  const qty = Number(order.get('quantity') || 0);
  const price = Number(order.get('price') || 0);
  const grossAmount = qty * price;
  const fees = calculateOrderFees(grossAmount, false);
  const netAmount = grossAmount + fees.totalFees;

  order.set('grossAmount', grossAmount);
  order.set('totalFees', fees.totalFees);
  order.set('netAmount', netAmount);
  order.set('executedQuantity', qty);
  order.set('remainingQuantity', 0);
  order.set('status', 'executed');

  await order.save(null, { useMasterKey: true });
}

module.exports = {
  finalizePairedBuyAfterCommit,
};
