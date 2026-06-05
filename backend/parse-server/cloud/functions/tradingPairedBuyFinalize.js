'use strict';

const { getUserStableId } = require('./tradingIdentity');
const {
  finalizePairedBuyAfterCommit,
  verifyPairedBuySettlement,
} = require('../utils/pairedBuyOrchestration');
const { runPairedBuySettlement } = require('../utils/pairedBuySettlementQueue');
const { semaphoreBusyError } = require('../utils/distributedSemaphore');

async function handleFinalizePairedBuyExecution(request) {
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader role required');
  }

  const { pairExecutionId } = request.params || {};
  if (!pairExecutionId || typeof pairExecutionId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'pairExecutionId required');
  }

  const pairId = pairExecutionId.trim();
  if (!pairId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'pairExecutionId must not be empty');
  }

  const traderId = getUserStableId(user);
  const PairedExecution = Parse.Object.extend('PairedExecution');
  let execution;
  try {
    execution = await new Parse.Query(PairedExecution).get(pairId, { useMasterKey: true });
  } catch (_) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'PairedExecution not found');
  }

  if (String(execution.get('traderId') || '') !== traderId) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Paired execution does not belong to this trader');
  }

  const executionStatus = String(execution.get('status') || '').toUpperCase();
  if (executionStatus === 'CANCELLED') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Paired execution was cancelled');
  }
  if (executionStatus === 'ABORTED') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Paired execution was aborted');
  }

  if (execution.get('effectsApplied') === true) {
    const check = await verifyPairedBuySettlement(pairId);
    if (check.ok) {
      const existingOrders = await new Parse.Query('Order')
        .equalTo('pairExecutionId', pairId)
        .ascending('createdAt')
        .find({ useMasterKey: true });

      return {
        pairExecutionId: pairId,
        idempotentReplay: true,
        status: 'SETTLED',
        orders: existingOrders.map((o) => ({
          orderId: o.id,
          legType: o.get('legType') || null,
          quantity: o.get('quantity') || 0,
          price: o.get('price') || 0,
          status: o.get('status') || null,
        })),
      };
    }
  }

  try {
    const queued = await runPairedBuySettlement(pairId, async () => {
      await finalizePairedBuyAfterCommit(pairId);
    });
    if (queued && queued.peerCompleted) {
      // Another worker finalized this pair while we waited on the distributed lock.
    }
  } catch (err) {
    if (err?.code === 'SEMAPHORE_TIMEOUT') {
      throw semaphoreBusyError('Paired buy finalize');
    }
    throw err;
  }

  const postCheck = await verifyPairedBuySettlement(pairId);
  if (!postCheck.ok) {
    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      `Paired buy settlement incomplete: ${postCheck.issues.join(', ')}`,
    );
  }

  const orders = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairId)
    .ascending('createdAt')
    .find({ useMasterKey: true });

  return {
    pairExecutionId: pairId,
    idempotentReplay: false,
    status: 'SETTLED',
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
  handleFinalizePairedBuyExecution,
};
