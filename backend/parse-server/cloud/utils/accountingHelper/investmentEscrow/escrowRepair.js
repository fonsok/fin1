'use strict';

const { TRANSACTION_TYPE, REFERENCE_TYPE } = require('./constants');

/**
 * Entfernt fehlerhafte `releaseTradingResidualCorrection`-Zeilen (Haben TRD +2,31).
 * Nur Alt-Bestand nach fehlgeschlagenem Backfill; neue Flows buchen diese Leg nicht.
 */
async function purgeEscrowLegEntries(investmentId, leg, tradeId) {
  const tradeKey = tradeId != null ? String(tradeId).trim() : '';
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  const toDestroy = rows.filter((e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return false;
    if (tradeKey && String(m.tradeId || '').trim() !== tradeKey) return false;
    return true;
  });
  if (toDestroy.length === 0) return 0;
  await Parse.Object.destroyAll(toDestroy, { useMasterKey: true });
  return toDestroy.length;
}

async function purgeReleaseTradingResidualCorrectionLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'releaseTradingResidualCorrection', tradeId);
}

async function purgeTradingResidualReturnLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'tradingResidualReturn', tradeId);
}

async function purgeReserveCapitalTradeSplitLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'reserveCapitalTradeSplit', tradeId);
}

async function purgeDeployReversalForCapitalSplitLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'deployReversalForCapitalSplit', tradeId);
}

module.exports = {
  purgeReleaseTradingResidualCorrectionLeg,
  purgeTradingResidualReturnLeg,
  purgeReserveCapitalTradeSplitLeg,
  purgeDeployReversalForCapitalSplitLeg,
};
