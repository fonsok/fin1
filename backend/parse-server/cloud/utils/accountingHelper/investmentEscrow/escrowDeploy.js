'use strict';

const { round2 } = require('../shared');
const { CLT_LIAB_PTR } = require('../clientLiabilityAccounts');
const { hasEscrowLeg, eigenbelegRefFromReserveLeg } = require('./ledgerQueries');
const { baseFields, buildPairedLedgerEntries, savePair } = require('./ledgerBuilders');

/**
 * reserved → active: RSV → TRD (Pool) optional mit Teilbetrag; Differenz zum
 * Reservierungs-Nominal (Investment.amount) geht RSV → AVA (Rest nach Zuteilung).
 *
 * @param {object} opts
 * @param {string} opts.investorId
 * @param {number} opts.amount – Betrag RSV→TRD (effektiv „Investment − Rest“ / Zuteilung)
 * @param {number} [opts.reservedNominal] – volles reserviertes Nominal; default = amount (nur RSV→TRD)
 * @param {string} opts.investmentId
 * @param {string} [opts.investmentNumber]
 * @param {string} [opts.businessCaseId]
 */
async function bookDeployToTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
  reservedNominal,
}) {
  const deployPrincipal = round2(Number(amount) || 0);
  const nominal = round2(
    reservedNominal !== undefined && reservedNominal !== null
      ? Number(reservedNominal)
      : deployPrincipal,
  );
  if (nominal <= 0) return;
  if (await hasEscrowLeg(investmentId, 'deploy')) return;

  const deployToTrd = round2(Math.min(nominal, Math.max(0, deployPrincipal)));
  const residualToAva = round2(Math.max(0, nominal - deployToTrd));

  if (deployToTrd <= 0) {
    if (residualToAva > 0) {
      console.error(
        `❌ bookDeployToTrading: Zuteilungsbetrag <= 0 bei positivem Nominal; keine Buchung (${investmentId})`,
      );
    }
    return;
  }

  const invNum = investmentNumber || '';
  const descTrd = `Kundenguthaben Handel/Pool${invNum ? ` (${invNum})` : ''} – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  const commonMeta = {
    investmentNumber: invNum,
    ...eigenbelegRef,
    ...(bc ? { businessCaseId: bc } : {}),
  };

  const rows = buildPairedLedgerEntries(
    'CLT-LIAB-RSV',
    CLT_LIAB_PTR,
    deployToTrd,
    baseFields(investorId, investmentId, 'deploy', descTrd, commonMeta),
  );
  if (residualToAva > 0) {
    const descAva = `Kundenguthaben Rest nach Pool-Zuteilung${invNum ? ` (${invNum})` : ''} – Investment ${investmentId}`;
    rows.push(...buildPairedLedgerEntries(
      'CLT-LIAB-RSV',
      'CLT-LIAB-AVA',
      residualToAva,
      baseFields(investorId, investmentId, 'deployResidualToAvailable', descAva, commonMeta),
    ));
  }
  await Parse.Object.saveAll(rows, { useMasterKey: true });
}

/**
 * Nach Erstellung einer PoolTradeParticipation: RSV→TRD = Zuteilung,
 * Rest des Nominals RSV→AVA (siehe `reservedNominal` in bookDeployToTrading).
 */
async function bookDeployForPoolParticipation(investment, allocatedAmount) {
  const nominal = round2(Number(investment.get('amount') || 0));
  const alloc = round2(Number(allocatedAmount) || 0);
  if (nominal <= 0) return;
  await bookDeployToTrading({
    investorId: investment.get('investorId'),
    amount: alloc,
    reservedNominal: nominal,
    investmentId: investment.id,
    investmentNumber: investment.get('investmentNumber') || '',
    businessCaseId: String(investment.get('businessCaseId') || '').trim(),
  });
}

/**
 * Storno vorheriger RSV→TRD-Deploy (volles Nominal), damit der Split aus RSV gebucht werden kann.
 */
async function bookDeployReversalForCapitalSplit({
  investorId,
  nominal,
  investmentId,
  investmentNumber,
  tradeId,
  businessCaseId,
}) {
  const nom = round2(nominal);
  if (nom <= 0) return;
  if (!(await hasEscrowLeg(investmentId, 'deploy'))) return;
  const leg = 'deployReversalForCapitalSplit';
  if (await hasEscrowLeg(investmentId, leg, { tradeId })) return;

  const invNum = investmentNumber || '';
  const desc = `Storno Pool-Zuführung vor Kapital-Split${invNum ? ` (${invNum})` : ''}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    CLT_LIAB_PTR,
    'CLT-LIAB-RSV',
    nom,
    baseFields(investorId, investmentId, leg, desc, {
      investmentNumber: invNum,
      tradeId: tradeId || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

module.exports = {
  bookDeployToTrading,
  bookDeployForPoolParticipation,
  bookDeployReversalForCapitalSplit,
};
