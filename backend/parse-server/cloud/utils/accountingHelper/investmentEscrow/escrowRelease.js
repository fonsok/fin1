'use strict';

const { round2 } = require('../shared');
const { CLT_LIAB_PTR } = require('../clientLiabilityAccounts');
const { audit } = require('../../structuredLogger');
const {
  hasEscrowLeg,
  sumEscrowLegCreditForTrade,
  sumCapitalSplitToAvailable,
  eigenbelegRefFromReserveLeg,
  sumPtrPoolCapitalReleasedForTrade,
  hasTradeSettlementEscrow,
} = require('./ledgerQueries');
const { baseFields, savePair } = require('./ledgerBuilders');

/**
 * reserved → cancelled (user storno): reserved → available
 */
async function bookReleaseReservation({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReserve')) return;
  const desc = `Reservierung aufgelöst${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReserve', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

async function bookReleaseTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  reason,
  businessCaseId,
}) {
  const gross = round2(amount);
  if (gross <= 0) return;
  if (reason !== 'refund' && await hasTradeSettlementEscrow(investmentId)) {
    audit.info('escrow.releaseTrading.skipSettled', {
      investmentId,
      businessCaseId,
      message: 'bookReleaseTrading: skipped — trade settlement escrow already booked',
    });
    return;
  }
  const residualReleased = await sumCapitalSplitToAvailable(investmentId);
  let amt = round2(Math.max(0, gross - residualReleased));
  if (amt <= 0) return;
  const ptrCredited = await sumEscrowLegCreditForTrade(investmentId, 'reserveCapitalTradeSplit', {
    account: CLT_LIAB_PTR,
  });
  if (ptrCredited > 0) {
    const ptrReleased = await sumPtrPoolCapitalReleasedForTrade(investmentId, '');
    const ptrRemaining = round2(Math.max(0, ptrCredited - ptrReleased));
    if (ptrRemaining <= 0) {
      audit.info('escrow.releaseTrading.skipEmptyPtr', {
        investmentId,
        businessCaseId,
        ptrCredited,
        ptrReleased,
        message: 'bookReleaseTrading: skipped — PTR pool capital already released',
      });
      return;
    }
    if (amt > ptrRemaining) {
      audit.warn('escrow.releaseTrading.ptrCap', {
        investmentId,
        businessCaseId,
        requested: amt,
        ptrRemaining,
        message: 'bookReleaseTrading: capped to remaining PTR balance',
      });
      amt = ptrRemaining;
    }
  }
  const leg = reason === 'refund' ? 'releaseTradingRefund' : 'releaseTradingComplete';
  if (await hasEscrowLeg(investmentId, leg)) return;
  const desc = reason === 'refund'
    ? `Handelsbindung Rückerstattung – Investment ${investmentId}`
    : `Handelsbindung Auflösung (Abschluss) – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    CLT_LIAB_PTR,
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, leg, desc, {
      investmentNumber: investmentNumber || '',
      reason: reason || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

/**
 * reserved → completed (no activate): reserved → available
 */
async function bookReleaseReservedOnComplete({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReservedComplete')) return;
  const desc = `Reserviert → verfügbar (Abschluss ohne Aktivierungspfad) – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReservedComplete', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

module.exports = {
  bookReleaseReservation,
  bookReleaseTrading,
  bookReleaseReservedOnComplete,
};
