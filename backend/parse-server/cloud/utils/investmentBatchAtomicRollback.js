'use strict';

const investmentEscrow = require('./accountingHelper/investmentEscrow');
const { round2 } = require('./accountingHelper/shared');
const {
  destroyReservationEigenbelegeForInvestment,
  rollbackOrphanInvestmentAfterFailedReserve,
} = require('./investmentReservationRollback');

/**
 * Reverts one split created in the current createInvestmentSplits request (GoB-aware).
 * reserved → release escrow (via cancel trigger) → remove row.
 */
async function rollbackCreatedSplitForAtomicBatch(investmentId, reason = '') {
  if (!investmentId) return;
  let inv;
  try {
    inv = await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
  } catch (e) {
    if (e && (e.code === 101 || e.code === Parse.Error.OBJECT_NOT_FOUND)) return;
    throw e;
  }

  const status = String(inv.get('status') || '').trim();
  const reservationStatus = String(inv.get('reservationStatus') || '').trim();
  const wasReserved = status === 'reserved' || reservationStatus === 'reserved';

  if (wasReserved) {
    try {
      inv.set('status', 'cancelled');
      inv.set('reservationStatus', 'cancelled');
      await inv.save(null, { useMasterKey: true });
    } catch (e) {
      console.error(`rollbackBatch: cancel save ${investmentId}:`, e.message);
      await rollbackOrphanInvestmentAfterFailedReserve(investmentId, reason);
      return;
    }
  } else if (status !== 'cancelled') {
    try {
      const investorId = inv.get('investorId');
      const amount = round2(inv.get('amount'));
      await investmentEscrow.bookReleaseReservation({
        investorId,
        amount,
        investmentId,
        investmentNumber: inv.get('investmentNumber') || '',
        businessCaseId: String(inv.get('businessCaseId') || '').trim(),
      });
    } catch (e) {
      console.error(`rollbackBatch: bookReleaseReservation ${investmentId}:`, e.message);
    }
    await rollbackOrphanInvestmentAfterFailedReserve(investmentId, reason);
    return;
  }

  try {
    await destroyReservationEigenbelegeForInvestment(investmentId);
    const row = await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
    await row.destroy({ useMasterKey: true });
    console.error(
      `rollbackBatch: Investment ${investmentId} entfernt (atomarer Batch-Rollback)${reason ? ` — ${reason}` : ''}`,
    );
  } catch (e) {
    if (e && (e.code === 101 || e.code === Parse.Error.OBJECT_NOT_FOUND)) return;
    console.error(`rollbackBatch: destroy ${investmentId}:`, e.message);
  }
}

/**
 * @param {string[]} investmentIds — neu in dieser Request angelegt (LIFO)
 */
async function rollbackBatchCreatedSplits(investmentIds, reason = '') {
  const ids = Array.isArray(investmentIds) ? investmentIds.filter(Boolean) : [];
  for (let i = ids.length - 1; i >= 0; i -= 1) {
    await rollbackCreatedSplitForAtomicBatch(ids[i], reason);
  }
}

module.exports = {
  rollbackCreatedSplitForAtomicBatch,
  rollbackBatchCreatedSplits,
};
