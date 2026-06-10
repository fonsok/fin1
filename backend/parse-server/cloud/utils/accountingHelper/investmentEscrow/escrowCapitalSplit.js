'use strict';

const { round2 } = require('../shared');
const { audit } = require('../../structuredLogger');
const {
  CLT_LIAB_AVA,
  CLT_LIAB_RSV,
  CLT_LIAB_PTR,
} = require('../clientLiabilityAccounts');
const { hasEscrowLeg, eigenbelegRefFromReserveLeg } = require('./ledgerQueries');
const { baseFields, buildSingleLedgerEntry, savePair } = require('./ledgerBuilders');
const { bookDeployReversalForCapitalSplit } = require('./escrowDeploy');

/**
 * GoB-Split aus Reservierung (1591) bei bekanntem Restbetrag:
 *   Soll CLT-LIAB-RSV (Nominal)
 *   Haben CLT_LIAB_PTR (Anschaffung / im Handel)
 *   Haben CLT-LIAB-AVA (Kunde Cash / Rest)
 * Idempotent pro investmentId + tradeId. Parallel: AccountStatement `residual_return`.
 */
async function bookReserveCapitalTradeSplit({
  investorId,
  nominal,
  tradingAmount,
  availableAmount,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  businessCaseId,
}) {
  const nom = round2(nominal);
  const trdAmt = round2(tradingAmount);
  const avaAmt = round2(availableAmount);
  if (nom <= 0) return;
  if (round2(trdAmt + avaAmt) !== nom) {
    audit.error('escrow.split.imbalance', {
      investmentId,
      tradeId: tradeId || null,
      tradeNumber: tradeNumber || null,
      businessCaseId,
      nominal: nom,
      tradingAmount: trdAmt,
      availableAmount: avaAmt,
      message: '❌ bookReserveCapitalTradeSplit: trading+available ≠ nominal',
    });
    return;
  }

  const leg = 'reserveCapitalTradeSplit';
  if (await hasEscrowLeg(investmentId, leg, { tradeId })) return;

  audit.info('escrow.split.book', {
    investmentId,
    investmentNumber: investmentNumber || null,
    tradeId: tradeId || null,
    tradeNumber: tradeNumber || null,
    businessCaseId,
    nominal: nom,
    tradingAmount: trdAmt,
    availableAmount: avaAmt,
    message: '📒 bookReserveCapitalTradeSplit: RSV Soll → PTR/AVA Haben',
  });

  const invNum = investmentNumber || '';
  const desc = `Kapital-Split Reservierung → Handel/verfügbar${invNum ? ` (${invNum})` : ''} – Trade #${tradeNumber || tradeId || ''}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  const splitGroupId = `${investmentId}:${tradeId || 'na'}:reserveCapitalTradeSplit`;

  if (avaAmt > 0 && (await hasEscrowLeg(investmentId, 'deploy'))) {
    await bookDeployReversalForCapitalSplit({
      investorId,
      nominal: nom,
      investmentId,
      investmentNumber: invNum,
      tradeId,
      businessCaseId: bc,
    });
  }

  const common = baseFields(investorId, investmentId, leg, desc, {
    investmentNumber: invNum,
    tradeId: tradeId || '',
    tradeNumber: tradeNumber || '',
    splitGroupId,
    nominal: nom,
    tradingAmount: trdAmt,
    availableAmount: avaAmt,
    ...eigenbelegRef,
    ...(bc ? { businessCaseId: bc } : {}),
  });

  if (avaAmt <= 0) {
    await savePair('CLT-LIAB-RSV', CLT_LIAB_PTR, nom, common);
    return;
  }

  const rows = [
    buildSingleLedgerEntry(CLT_LIAB_RSV, 'debit', nom, common, { splitPart: 'reserve' }),
    buildSingleLedgerEntry(CLT_LIAB_PTR, 'credit', trdAmt, common, { splitPart: 'poolCapital' }),
    buildSingleLedgerEntry(CLT_LIAB_AVA, 'credit', avaAmt, common, { splitPart: 'available' }),
  ];
  await Parse.Object.saveAll(rows, { useMasterKey: true });
}

/** @deprecated – nutzt bookReserveCapitalTradeSplit; nur für Alt-Aufrufe. */
async function bookTradingResidualReturn({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  businessCaseId,
  nominal,
}) {
  const avaAmt = round2(amount);
  if (avaAmt <= 0) return;
  const nom = round2(nominal != null ? nominal : 0);
  if (nom <= 0) {
    console.error(`❌ bookTradingResidualReturn: nominal fehlt (${investmentId})`);
    return;
  }
  await bookReserveCapitalTradeSplit({
    investorId,
    nominal: nom,
    tradingAmount: round2(nom - avaAmt),
    availableAmount: avaAmt,
    investmentId,
    investmentNumber,
    tradeId,
    tradeNumber,
    businessCaseId,
  });
}

module.exports = {
  bookReserveCapitalTradeSplit,
  bookTradingResidualReturn,
};
