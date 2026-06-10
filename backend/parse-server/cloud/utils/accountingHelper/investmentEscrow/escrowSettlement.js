'use strict';

const { round2 } = require('../shared');
const { audit } = require('../../structuredLogger');
const { CLT_LIAB_AVA, CLT_LIAB_PTR, CLT_LIAB_PPS } = require('../clientLiabilityAccounts');
const { CLT_EQT_INV_PNL } = require('./constants');
const {
  hasEscrowLeg,
  sumEscrowLegCreditForTrade,
  sumPartialSellPpsPendingForTrade,
  sumEscrowLegDebitForTrade,
  eigenbelegRefFromReserveLeg,
} = require('./ledgerQueries');
const { baseFields, savePair } = require('./ledgerBuilders');

/**
 * Trade-Settlement (Collection Bill): Pool-Kapital PTR→AVA + Investor-Gewinn P/L→AVA.
 * SSOT Überweisungsbetrag = netSellAmount − commission ≈ tradingAmount + netProfit.
 * Idempotent pro investmentId + tradeId.
 */
async function bookTradeSettlementPayout({
  investorId,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  tradingAmount,
  netProfit,
  transferAmount,
  businessCaseId,
  collectionBillRef = {},
}) {
  const poolAmt = round2(tradingAmount);
  const profitAmt = round2(netProfit);
  const payoutTotal = round2(transferAmount ?? round2(poolAmt + profitAmt));
  if (payoutTotal <= 0) return;

  const invNum = investmentNumber || '';
  const desc = `Trade-Abwicklung${invNum ? ` (${invNum})` : ''} – Trade #${tradeNumber || tradeId || ''}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  const billRef = {
    referenceDocumentId: collectionBillRef.referenceDocumentId || '',
    referenceDocumentNumber: collectionBillRef.referenceDocumentNumber || '',
  };

  const componentSum = round2(poolAmt + profitAmt);
  const roundingGap = round2(payoutTotal - componentSum);
  if (Math.abs(roundingGap) >= 0.02) {
    audit.warn('escrow.payout.gap', {
      investmentId,
      tradeId,
      tradeNumber: tradeNumber || null,
      businessCaseId,
      transferAmount: payoutTotal,
      poolAmount: poolAmt,
      profitAmount: profitAmt,
      componentSum,
      gap: roundingGap,
      message: '⚠️ bookTradeSettlementPayout: transfer ≠ pool+net',
    });
  }

  const partialPoolCostReleased = tradeId
    ? await sumEscrowLegDebitForTrade(investmentId, 'partialSellRelease', {
      tradeId,
      account: CLT_LIAB_PTR,
    })
    : 0;
  const partialGrossProfitRecognized = tradeId
    ? await sumEscrowLegCreditForTrade(investmentId, 'partialSellProfitRecognition', {
      tradeId,
      account: CLT_LIAB_PPS,
    })
    : 0;
  const partialPpsPending = tradeId
    ? await sumPartialSellPpsPendingForTrade(investmentId, tradeId)
    : 0;
  const ptrCredited = tradeId
    ? await sumEscrowLegCreditForTrade(investmentId, 'reserveCapitalTradeSplit', {
      tradeId,
      account: CLT_LIAB_PTR,
    })
    : 0;
  const effectivePoolAmt = ptrCredited > 0 ? ptrCredited : poolAmt;
  const ptrReleaseFromPool = round2(Math.max(0, effectivePoolAmt - partialPoolCostReleased));
  const ptrRemainingOnLedger = ptrCredited > 0
    ? round2(Math.max(0, ptrCredited - partialPoolCostReleased))
    : ptrReleaseFromPool;
  const ptrReleaseAmt = round2(Math.min(ptrReleaseFromPool, ptrRemainingOnLedger));
  if (ptrCredited > 0 && ptrReleaseAmt < round2(Math.max(0, poolAmt - partialPoolCostReleased))) {
    audit.warn('escrow.settlement.ptrCap', {
      investmentId,
      tradeId,
      tradeNumber: tradeNumber || null,
      businessCaseId,
      poolAmtFromBeleg: poolAmt,
      ptrCredited,
      partialPoolCostReleased,
      ptrReleaseAmt,
      message: 'bookTradeSettlementPayout: PTR release capped to ledger balance',
    });
  }
  const profitReleaseAmt = round2(Math.max(0, profitAmt - partialGrossProfitRecognized));

  if (ptrReleaseAmt > 0 && !(await hasEscrowLeg(investmentId, 'tradeSettlementPoolRelease', { tradeId }))) {
    await savePair(
      CLT_LIAB_PTR,
      CLT_LIAB_AVA,
      ptrReleaseAmt,
      baseFields(investorId, investmentId, 'tradeSettlementPoolRelease', desc, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        poolCapitalReleased: ptrReleaseAmt,
        partialPoolReleasedPrior: partialPoolCostReleased,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }

  if (partialPpsPending > 0
    && !(await hasEscrowLeg(investmentId, 'tradeSettlementPartialPoolRelease', { tradeId }))) {
    await savePair(
      CLT_LIAB_PPS,
      CLT_LIAB_AVA,
      partialPpsPending,
      baseFields(investorId, investmentId, 'tradeSettlementPartialPoolRelease', desc, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        poolCapitalReleased: partialPoolCostReleased,
        partialGrossProfitRecognized,
        partialPpsPending,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }

  if (profitReleaseAmt > 0 && !(await hasEscrowLeg(investmentId, 'tradeSettlementProfitRelease', { tradeId }))) {
    await savePair(
      CLT_EQT_INV_PNL,
      CLT_LIAB_AVA,
      profitReleaseAmt,
      baseFields(investorId, investmentId, 'tradeSettlementProfitRelease', desc, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        netProfitReleased: profitReleaseAmt,
        partialGrossProfitRecognizedPrior: partialGrossProfitRecognized,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }

  const gapToBook = round2(payoutTotal - poolAmt - profitAmt);
  if (Math.abs(gapToBook) >= 0.01
    && !(await hasEscrowLeg(investmentId, 'tradeSettlementTransferGap', { tradeId }))) {
    await savePair(
      CLT_EQT_INV_PNL,
      CLT_LIAB_AVA,
      Math.abs(gapToBook),
      baseFields(investorId, investmentId, 'tradeSettlementTransferGap', `${desc} (Ausgleich)`, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        roundingGap: gapToBook,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }
}

module.exports = {
  bookTradeSettlementPayout,
};
