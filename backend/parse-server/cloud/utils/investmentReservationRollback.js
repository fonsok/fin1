'use strict';

/**
 * Parse Server persists the object BEFORE afterSave runs; throwing in afterSave does NOT
 * roll back the row. If Kundenguthaben-Reservierung (Eigenbeleg + AppLedger) fails, we must
 * remove the orphan Investment (and reservation Eigenbeleg rows) explicitly.
 */

async function destroyReservationEigenbelegeForInvestment(investmentId) {
  if (!investmentId) return;
  const q = new Parse.Query('Document');
  q.equalTo('investmentId', investmentId);
  q.equalTo('type', 'investmentReservationEigenbeleg');
  q.equalTo('source', 'backend');
  const rows = await q.find({ useMasterKey: true });
  if (rows.length === 0) return;
  await Parse.Object.destroyAll(rows, { useMasterKey: true });
}

/**
 * @param {string} investmentId
 * @param {string} [reason] — nur Logging
 */
async function rollbackOrphanInvestmentAfterFailedReserve(investmentId, reason = '') {
  if (!investmentId) return;
  try {
    await destroyReservationEigenbelegeForInvestment(investmentId);
  } catch (e) {
    console.error(`rollbackOrphanInvestment: Document cleanup ${investmentId}:`, e.message);
  }
  try {
    const inv = await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
    await inv.destroy({ useMasterKey: true });
    console.error(
      `rollbackOrphanInvestment: Investment ${investmentId} entfernt nach fehlgeschlagener Reservierung${reason ? ` (${reason})` : ''}`,
    );
  } catch (e) {
    if (e && (e.code === Parse.Error.OBJECT_NOT_FOUND || e.code === 101)) {
      return;
    }
    console.error(`rollbackOrphanInvestment: Investment ${investmentId} destroy:`, e.message);
  }
}

module.exports = {
  rollbackOrphanInvestmentAfterFailedReserve,
  destroyReservationEigenbelegeForInvestment,
};
