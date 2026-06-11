'use strict';

const { round2 } = require('../shared');
const { postLedgerPair } = require('../journal');
const { createAppCommissionEigenbeleg } = require('../documents');
const { resolveDocumentReference } = require('../documentReferenceResolver');

/**
 * GoB: Eigenbeleg → App-Ledger (ADR-010: PLT-LIAB-COM → PLT-REV-COM).
 * Idempotent per trade via metadata.leg = `app_commission`.
 */
async function bookAppCommissionRevenueIfDue({
  totalAppCommission,
  trade,
  tradeId,
  tradeNumber,
  traderId,
  appCommissionRate,
  grossProfitBasis,
  businessCaseId,
}) {
  const resolvedTradeId = trade?.id || tradeId;
  if (!resolvedTradeId || totalAppCommission <= 0) {
    return null;
  }

  const tradeForBeleg = trade || {
    id: resolvedTradeId,
    get(key) {
      if (key === 'tradeNumber') return tradeNumber;
      if (key === 'traderId') return traderId;
      return undefined;
    },
  };

  const eigenbeleg = await createAppCommissionEigenbeleg({
    trade: tradeForBeleg,
    traderId,
    totalAppCommission,
    appCommissionRate,
    grossProfitBasis,
    businessCaseId,
  });
  if (!eigenbeleg) {
    throw new Error(
      `GoB fail-closed: App-Provision Eigenbeleg missing for trade ${resolvedTradeId}`,
    );
  }

  const belegRef = resolveDocumentReference(eigenbeleg, { context: 'app_commission_eigenbeleg' });
  const resolvedTradeNumber = tradeNumber
    ?? tradeForBeleg.get?.('tradeNumber')
    ?? '';

  await postLedgerPair({
    debitAccount: 'PLT-LIAB-COM',
    creditAccount: 'PLT-REV-COM',
    amount: round2(totalAppCommission),
    userRole: 'platform',
    transactionType: 'appCommission',
    referenceId: resolvedTradeId,
    referenceType: 'Trade',
    description: `Plattform-Provision Trade #${resolvedTradeNumber}`,
    leg: 'app_commission',
    metadata: {
      businessCaseId: businessCaseId || null,
      tradeNumber: resolvedTradeNumber || null,
      referenceDocumentId: belegRef.referenceDocumentId,
      referenceDocumentNumber: belegRef.referenceDocumentNumber,
    },
  });

  return {
    totalAppCommission: round2(totalAppCommission),
    eigenbelegId: belegRef.referenceDocumentId,
    eigenbelegNumber: belegRef.referenceDocumentNumber,
  };
}

module.exports = {
  bookAppCommissionRevenueIfDue,
};
