'use strict';

const { round2 } = require('../shared');
const { audit } = require('../../structuredLogger');
const { CLT_LIAB_PTR, CLT_LIAB_PPS } = require('../clientLiabilityAccounts');
const { CLT_EQT_INV_PNL } = require('./constants');
const {
  hasEscrowLeg,
  sumEscrowLegCreditForTrade,
  sumPtrPoolCapitalReleasedForTrade,
} = require('./ledgerQueries');
const { baseFields, savePair } = require('./ledgerBuilders');

/**
 * ADR-015: Partial Sell — proportional pool capital PTR→PPS (idempotent per sellOrderId).
 * GoB: internal beleg must exist before this call.
 */
async function bookPartialSellPoolRelease({
  investorId,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  sellOrderId,
  poolCapitalReleased,
  businessCaseId,
  internalBelegRef = {},
}) {
  let amount = round2(poolCapitalReleased);
  const sellKey = String(sellOrderId || '').trim();
  if (amount <= 0 || !sellKey || !tradeId) return;

  if (await hasEscrowLeg(investmentId, 'partialSellRelease', { tradeId, sellOrderId: sellKey })) {
    return;
  }

  const ptrCredited = await sumEscrowLegCreditForTrade(investmentId, 'reserveCapitalTradeSplit', {
    tradeId,
    account: CLT_LIAB_PTR,
  });
  if (ptrCredited > 0) {
    const ptrAlreadyReleased = await sumPtrPoolCapitalReleasedForTrade(investmentId, tradeId);
    const ptrRemaining = round2(Math.max(0, ptrCredited - ptrAlreadyReleased));
    if (ptrRemaining <= 0) {
      audit.warn('escrow.partialSell.ptrExhausted', {
        investmentId,
        tradeId,
        tradeNumber: tradeNumber || null,
        sellOrderId: sellKey,
        requested: amount,
        ptrCredited,
        ptrAlreadyReleased,
        message: 'bookPartialSellPoolRelease: no PTR pool capital left for trade (1592)',
      });
      return;
    }
    if (amount > ptrRemaining) {
      audit.warn('escrow.partialSell.ptrCap', {
        investmentId,
        tradeId,
        tradeNumber: tradeNumber || null,
        sellOrderId: sellKey,
        requested: amount,
        ptrRemaining,
        ptrCredited,
        message: 'bookPartialSellPoolRelease: PTR release capped to ledger balance',
      });
      amount = ptrRemaining;
    }
  }

  const invNum = investmentNumber || '';
  const desc = `Teilverkauf Pool-Trade${invNum ? ` (${invNum})` : ''} – Trade #${tradeNumber || tradeId}`;
  const bc = String(businessCaseId || '').trim();
  const billRef = {
    referenceDocumentId: internalBelegRef.referenceDocumentId || '',
    referenceDocumentNumber: internalBelegRef.referenceDocumentNumber || '',
  };

  await savePair(
    CLT_LIAB_PTR,
    CLT_LIAB_PPS,
    amount,
    baseFields(investorId, investmentId, 'partialSellRelease', desc, {
      investmentNumber: invNum,
      tradeId: tradeId || '',
      tradeNumber: tradeNumber || '',
      sellOrderId: sellKey,
      poolCapitalReleased: amount,
      ...billRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

/**
 * ADR-015: Brutto-Gewinn der Partial-Sell-Scheibe sofort intern (GoB) — INV-PNL → PPS.
 * Provision/Kundenauszahlung bleiben bis Trade-Ende. Idempotent pro sellOrderId.
 */
async function bookPartialSellProfitRecognition({
  investorId,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  sellOrderId,
  grossProfit,
  businessCaseId,
  internalBelegRef = {},
}) {
  const amount = round2(grossProfit);
  const sellKey = String(sellOrderId || '').trim();
  if (amount <= 0 || !sellKey || !tradeId) return;

  if (await hasEscrowLeg(investmentId, 'partialSellProfitRecognition', { tradeId, sellOrderId: sellKey })) {
    return;
  }

  const invNum = investmentNumber || '';
  const desc = `Teilverkauf-Gewinn Pool-Trade${invNum ? ` (${invNum})` : ''} – Trade #${tradeNumber || tradeId}`;
  const bc = String(businessCaseId || '').trim();
  const billRef = {
    referenceDocumentId: internalBelegRef.referenceDocumentId || '',
    referenceDocumentNumber: internalBelegRef.referenceDocumentNumber || '',
  };

  await savePair(
    CLT_EQT_INV_PNL,
    CLT_LIAB_PPS,
    amount,
    baseFields(investorId, investmentId, 'partialSellProfitRecognition', desc, {
      investmentNumber: invNum,
      tradeId: tradeId || '',
      tradeNumber: tradeNumber || '',
      sellOrderId: sellKey,
      grossProfitRecognized: amount,
      ...billRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

module.exports = {
  bookPartialSellPoolRelease,
  bookPartialSellProfitRecognition,
};
