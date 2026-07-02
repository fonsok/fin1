'use strict';

const { getTraderCommissionRate, loadConfig } = require('../../configHelper/index.js');
const { round2 } = require('../shared');
const { calculateWithholdingBundle, resolveUserTaxProfile } = require('../taxation');
const { createCreditNoteDocument } = require('../documents');
const { resolveDocumentReference } = require('../documentReferenceResolver');
const { bookSettlementEntry } = require('../statements');
const { bookTraderTaxEntries } = require('../settlementTaxEntries');

async function loadTraderCommissionIdempotency(commissionTradeId) {
  const existingTraderCommissionEntry = await new Parse.Query('AccountStatement')
    .equalTo('tradeId', commissionTradeId)
    .equalTo('entryType', 'commission_credit')
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  const existingCreditNote = await new Parse.Query('Document')
    .equalTo('type', 'traderCreditNote')
    .equalTo('tradeId', commissionTradeId)
    .equalTo('source', 'backend')
    .first({ useMasterKey: true });

  return Boolean(existingTraderCommissionEntry || existingCreditNote);
}

/**
 * Trader provision (commission_credit + Gutschrift) after all investor participations settle.
 */
async function bookTraderCommissionCreditIfDue({
  totalCommission,
  traderCreditAlreadyBooked,
  traderBookingTrade,
  lifecycleTradeStatus,
  traderId,
  commissionTradeNumber,
  creditNoteGrossProfit,
  netTradingProfit,
  investorBreakdown,
  businessCaseId,
  commissionRate: commissionRateOverride,
}) {
  if (
    totalCommission <= 0
    || traderCreditAlreadyBooked
    || !traderBookingTrade
    || lifecycleTradeStatus !== 'completed'
  ) {
    return null;
  }

  const commissionRate = Number.isFinite(commissionRateOverride)
    ? commissionRateOverride
    : await getTraderCommissionRate();
  const config = await loadConfig();
  const taxConfig = config.tax || {};
  const traderProfile = await resolveUserTaxProfile(traderId);

  const traderTaxBreakdown = calculateWithholdingBundle({
    taxableAmount: totalCommission,
    taxConfig,
    userProfile: traderProfile,
  });
  const creditNote = await createCreditNoteDocument({
    traderId,
    trade: traderBookingTrade,
    totalCommission: round2(totalCommission),
    commissionRate,
    grossProfit: round2(creditNoteGrossProfit),
    netProfit: round2(creditNoteGrossProfit - totalCommission),
    investorBreakdown,
    taxBreakdown: traderTaxBreakdown,
    businessCaseId,
  });
  const creditNoteRef = resolveDocumentReference(creditNote, { context: 'commission_credit' });

  await bookSettlementEntry({
    userId: traderId,
    userRole: 'trader',
    entryType: 'commission_credit',
    amount: round2(totalCommission),
    tradeId: traderBookingTrade.id,
    tradeNumber: commissionTradeNumber,
    description: `Provisionsgutschrift Trade #${commissionTradeNumber}`,
    ...creditNoteRef,
    businessCaseId,
  });

  if (traderTaxBreakdown.totalTax > 0) {
    await bookTraderTaxEntries({
      traderId,
      trade: traderBookingTrade,
      tradeNumber: commissionTradeNumber,
      creditNoteId: creditNoteRef.referenceDocumentId,
      creditNoteNumber: creditNoteRef.referenceDocumentNumber,
      taxBreakdown: traderTaxBreakdown,
      bookSettlementEntry,
      businessCaseId,
    });
  }

  return {
    commissionRate,
    taxConfig,
    traderProfile,
    traderTaxBreakdown,
  };
}

module.exports = {
  loadTraderCommissionIdempotency,
  bookTraderCommissionCreditIfDue,
};
