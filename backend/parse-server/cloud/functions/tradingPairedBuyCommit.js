'use strict';

const { getUserStableId } = require('./tradingIdentity');
const { handleFinalizePairedBuyExecution } = require('./tradingPairedBuyFinalize');
const { advancePairedOrderLegsStatus } = require('../utils/pairedOrderStatusCoupling');
const { verifyPairedBuySettlement } = require('../utils/pairedBuyOrchestration');

/**
 * Single commit step for paired buy: finalize (TRADER + MIRROR_POOL executed, pool activation)
 * and optional post-execution display status (confirmed / completed) in one round-trip.
 */
async function handleCommitPairedBuyExecution(request) {
  const { pairExecutionId, postDisplayStatus } = request.params || {};
  const post = String(postDisplayStatus || '').trim().toLowerCase();
  const pairId = String(pairExecutionId || '').trim();

  if (post && !['confirmed', 'completed'].includes(post)) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'postDisplayStatus must be confirmed or completed',
    );
  }

  if (post && pairId) {
    const execution = await new Parse.Query('PairedExecution')
      .get(pairId, { useMasterKey: true })
      .catch(() => null);
    if (execution?.get('effectsApplied') === true) {
      const check = await verifyPairedBuySettlement(pairId);
      if (check.ok) {
        const user = request.user;
        if (!user) {
          throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
        }
        const traderId = getUserStableId(user);
        await advancePairedOrderLegsStatus(pairId, traderId, post);
        const orders = await new Parse.Query('Order')
          .equalTo('pairExecutionId', pairId)
          .ascending('createdAt')
          .find({ useMasterKey: true });
        return {
          pairExecutionId: pairId,
          status: 'SETTLED',
          committed: true,
          postDisplayStatus: post,
          postOnly: true,
          orders: orders.map((o) => ({
            orderId: o.id,
            legType: o.get('legType') || null,
            quantity: o.get('quantity') || 0,
            price: o.get('price') || 0,
            status: o.get('status') || null,
          })),
        };
      }
    }
  }

  const result = await handleFinalizePairedBuyExecution(request);

  if (!post || result.status !== 'SETTLED') {
    return { ...result, committed: true };
  }

  if (!['confirmed', 'completed'].includes(post)) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'postDisplayStatus must be confirmed or completed',
    );
  }

  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }

  const resolvedPairId = String(pairExecutionId || result.pairExecutionId || '').trim();
  if (!resolvedPairId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'pairExecutionId required');
  }

  const traderId = getUserStableId(user);
  await advancePairedOrderLegsStatus(resolvedPairId, traderId, post);

  const orders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', resolvedPairId)
    .ascending('createdAt')
    .find({ useMasterKey: true });

  return {
    ...result,
    committed: true,
    postDisplayStatus: post,
    orders: orders.map((o) => ({
      orderId: o.id,
      legType: o.get('legType') || null,
      quantity: o.get('quantity') || 0,
      price: o.get('price') || 0,
      status: o.get('status') || null,
    })),
  };
}

module.exports = {
  handleCommitPairedBuyExecution,
};
