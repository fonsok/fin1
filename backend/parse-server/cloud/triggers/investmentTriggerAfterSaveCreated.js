'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { rollbackOrphanInvestmentAfterFailedReserve } = require('../utils/investmentReservationRollback');
const {
  formatCurrency,
  createNotification,
  logComplianceEvent,
} = require('./investmentTriggerHelpers');

async function handleInvestmentAfterSaveCreated(investment) {
  const investorId = investment.get('investorId');
  const traderId = investment.get('traderId');
  const amount = investment.get('amount');
  const invId = investment.id;

  // GoB: Reservierung (Eigenbeleg + CLT-LIAB AVA→RSV) muss gelingen.
  // WICHTIG: Parse speichert das Objekt VOR afterSave — ein throw rollt die Zeile NICHT zurück.
  // Bei Fehler: Investment + ggf. Eigenbeleg explizit löschen, dann Fehler an Client.
  let reserveResult;
  try {
    reserveResult = await investmentEscrow.bookReserve({
      investorId,
      amount: round2(amount),
      investmentId: invId,
      investmentNumber: investment.get('investmentNumber') || '',
      parseInvestment: investment,
    });
  } catch (err) {
    console.error(`❌ bookReserve Exception ${invId}:`, err.message);
    await rollbackOrphanInvestmentAfterFailedReserve(invId, err.message);
    throw err;
  }

  if (!reserveResult || reserveResult.ok === false) {
    const detail = reserveResult && reserveResult.detail ? ` (${reserveResult.detail})` : '';
    const reason = (reserveResult && reserveResult.reason) || 'unknown';
    console.error(`❌ bookReserve fehlgeschlagen ${invId}: ${reason}${detail}`);
    await rollbackOrphanInvestmentAfterFailedReserve(invId, reason);
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Kundenguthaben-Reservierung fehlgeschlagen (GoB / Hauptbuch): ${reason}`,
    );
  }
  if (reserveResult.skipped === 'non_positive') {
    await rollbackOrphanInvestmentAfterFailedReserve(invId, 'non_positive');
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'Investment-Betrag ungültig für Reservierung.',
    );
  }

  try {
    await createNotification(investorId, 'investment_created', 'investment',
      'Investment erstellt',
      `Ihr Investment über ${formatCurrency(amount)} wurde erstellt. ` +
        'Bitte bestätigen Sie innerhalb von 24 Stunden.');

    await createNotification(traderId, 'investment_created', 'investment',
      'Neues Investment',
      `Ein neuer Investor hat ${formatCurrency(amount)} in Ihren Pool investiert.`);

    await logComplianceEvent(investorId, 'order_placed', 'info',
      `Investment created: ${investment.get('investmentNumber')}`,
      { amount, traderId });
  } catch (err) {
    console.error(`⚠️ investment_created Benachrichtigung/Audit nach bookReserve ${investment.id}:`, err.message);
  }
}

module.exports = {
  handleInvestmentAfterSaveCreated,
};
