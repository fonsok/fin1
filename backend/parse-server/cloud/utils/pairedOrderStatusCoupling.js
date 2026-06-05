'use strict';

const {
  CANCELLABLE_STATUSES,
  PAIRED_STATUS_BATCH_CONTEXT_KEY,
  normalizeStatus,
  isCancellableStatus,
  pairedStatusBatchContext,
} = require('./pairedOrderShared');

/** Canonical buy-order progression (single step at a time via advancePairedOrderStatus). */
const STATUS_PROGRESSION = ['pending', 'submitted', 'suspended', 'executed', 'confirmed', 'completed'];

function statusRank(status) {
  const n = normalizeStatus(status);
  const idx = STATUS_PROGRESSION.indexOf(n);
  return idx >= 0 ? idx : -1;
}

function canAdvanceOneStep(fromStatus, toStatus) {
  const from = normalizeStatus(fromStatus);
  const to = normalizeStatus(toStatus);
  if (to === 'cancelled') return false;
  if (from === to) return true;
  const fromIdx = statusRank(from);
  const toIdx = statusRank(to);
  if (fromIdx < 0 || toIdx < 0) return false;
  return toIdx === fromIdx + 1;
}

/** Next canonical step on the progression ladder, or null. */
function nextStepStatus(currentStatus) {
  const idx = statusRank(currentStatus);
  if (idx < 0 || idx >= STATUS_PROGRESSION.length - 1) return null;
  return STATUS_PROGRESSION[idx + 1];
}

/**
 * True when `target` is reachable from `current` by forward steps on STATUS_PROGRESSION
 * (e.g. pending → submitted → suspended in one API call).
 */
function canReachStatusForward(currentStatus, targetStatus) {
  const target = normalizeStatus(targetStatus);
  const targetIdx = statusRank(target);
  if (targetIdx < 0) return false;
  let cursor = normalizeStatus(currentStatus);
  if (statusRank(cursor) < 0) return false;
  if (statusRank(cursor) > targetIdx) return false;
  while (cursor !== target) {
    const step = nextStepStatus(cursor);
    if (!step || statusRank(step) > targetIdx) return false;
    cursor = step;
  }
  return true;
}

/**
 * @param {string} pairExecutionId
 * @returns {Promise<Parse.Object[]>}
 */
async function loadPairedOrderLegs(pairExecutionId) {
  const pairId = String(pairExecutionId || '').trim();
  if (!pairId) return [];
  return new Parse.Query('Order')
    .equalTo('pairExecutionId', pairId)
    .ascending('createdAt')
    .find({ useMasterKey: true });
}

/**
 * @param {Parse.Object[]} legs
 * @returns {string|null} first non-empty normalized status, or null
 */
function pairedLegsCanonicalStatus(legs) {
  if (!legs.length) return null;
  const statuses = legs.map((o) => normalizeStatus(o.get('status')));
  const unique = [...new Set(statuses)];
  if (unique.length === 1) return unique[0];
  return null;
}

function applyStatusTimestamps(order, status) {
  const now = new Date();
  const s = normalizeStatus(status);
  if (s === 'executed' && !order.get('executedAt')) {
    order.set('executedAt', now);
  }
  if (s === 'confirmed' && !order.get('confirmedAt')) {
    order.set('confirmedAt', now);
  }
  if (s === 'cancelled' && !order.get('cancelledAt')) {
    order.set('cancelledAt', now);
  }
}

/**
 * Reject single-leg status patches that would desync paired buy legs.
 * Batch saves (finalize / advance / cancel) set context.pairedStatusBatch.
 *
 * @param {Parse.Object} order
 * @param {object} request — Parse beforeSave request
 */
async function assertPairedOrderStatusCouplingOnSave(order, request) {
  if (request.context && request.context[PAIRED_STATUS_BATCH_CONTEXT_KEY] === true) {
    return;
  }
  if (!request.original) return;

  const newStatus = normalizeStatus(order.get('status'));
  if (newStatus === 'cancelled') {
    return;
  }

  const pairId = String(order.get('pairExecutionId') || '').trim();
  if (!pairId) return;

  const oldStatus = request.original.get('status');
  if (normalizeStatus(oldStatus) === newStatus) return;

  const legs = await loadPairedOrderLegs(pairId);
  if (legs.length < 2) return;

  const canonical = pairedLegsCanonicalStatus(
    legs.map((leg) => (leg.id === order.id ? order : leg)),
  );

  if (canonical === null) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Paired order legs have diverged status — use advancePairedOrderStatus, finalizePairedBuyExecution, or cancelOrder',
    );
  }

  if (canonical !== newStatus) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Paired order legs must stay in sync (expected all "${canonical}", got "${newStatus}" on one leg)`,
    );
  }
}

/**
 * Advance all legs of a paired buy by one UI progression step (not `executed`).
 *
 * @param {string} pairExecutionId
 * @param {string} traderId
 * @param {string} nextStatus
 */
async function advancePairedOrderLegsStatus(pairExecutionId, traderId, nextStatus) {
  const pairId = String(pairExecutionId || '').trim();
  const target = normalizeStatus(nextStatus);
  if (!pairId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'pairExecutionId required');
  }
  if (!target) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'status required');
  }
  if (target === 'executed') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Use finalizePairedBuyExecution to move paired buy legs to executed',
    );
  }
  if (target === 'cancelled') {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Use cancelOrder to cancel paired buy legs',
    );
  }

  const PairedExecution = Parse.Object.extend('PairedExecution');
  let execution;
  try {
    execution = await new Parse.Query(PairedExecution).get(pairId, { useMasterKey: true });
  } catch (_) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'PairedExecution not found');
  }

  if (String(execution.get('traderId') || '') !== String(traderId || '').trim()) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Paired execution does not belong to this trader');
  }

  const executionStatus = String(execution.get('status') || '').toUpperCase();
  if (executionStatus === 'CANCELLED' || executionStatus === 'ABORTED') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, `Paired execution is ${executionStatus}`);
  }
  if (execution.get('effectsApplied') === true && statusRank(target) <= statusRank('executed')) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Paired execution already settled — cannot rewind order status',
    );
  }

  const legs = await loadPairedOrderLegs(pairId);
  if (!legs.length) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'No orders for paired execution');
  }

  const ownerId = String(traderId || '').trim();
  for (const leg of legs) {
    if (String(leg.get('traderId') || '').trim() !== ownerId) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Order does not belong to this trader');
    }
  }

  const current = pairedLegsCanonicalStatus(legs);
  if (current === null) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Paired order legs have diverged status — admin repair required',
    );
  }

  if (statusRank(target) > statusRank('suspended') && statusRank(current) < statusRank('executed')) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Use finalizePairedBuyExecution before advancing past executed',
    );
  }

  if (current === target) {
    return {
      pairExecutionId: pairId,
      previousStatus: current,
      status: target,
      orderIds: legs.map((o) => o.id),
      legCount: legs.length,
      idempotentReplay: true,
    };
  }

  if (!canReachStatusForward(current, target)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Cannot advance paired orders from "${current}" to "${target}"`,
    );
  }

  if (!isCancellableStatus(current) && statusRank(target) < statusRank('executed')) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Paired orders cannot move backward from "${current}"`,
    );
  }

  for (const leg of legs) {
    if (String(leg.get('tradeId') || '').trim() && statusRank(target) < statusRank('executed')) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        'Order already linked to a trade — status rollback not allowed',
      );
    }
    leg.set('status', target);
    applyStatusTimestamps(leg, target);
    if (target === 'completed' || target === 'cancelled') {
      leg.set('remainingQuantity', 0);
    }
  }

  await Parse.Object.saveAll(legs, {
    useMasterKey: true,
    context: { [PAIRED_STATUS_BATCH_CONTEXT_KEY]: true },
  });

  return {
    pairExecutionId: pairId,
    previousStatus: current,
    status: target,
    orderIds: legs.map((o) => o.id),
    legCount: legs.length,
  };
}

module.exports = {
  STATUS_PROGRESSION,
  PAIRED_STATUS_BATCH_CONTEXT_KEY,
  normalizeStatus,
  statusRank,
  canAdvanceOneStep,
  nextStepStatus,
  canReachStatusForward,
  loadPairedOrderLegs,
  pairedLegsCanonicalStatus,
  assertPairedOrderStatusCouplingOnSave,
  advancePairedOrderLegsStatus,
  pairedStatusBatchContext,
  CANCELLABLE_STATUSES,
};
