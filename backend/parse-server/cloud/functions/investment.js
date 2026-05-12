// ============================================================================
// Parse Cloud Code
// functions/investment.js - Investment Functions
// ============================================================================

'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { validateInvestmentAmountAgainstLimits } = require('../utils/investmentLimitsValidation');
const { getAppServiceChargeRateForAccountType } = require('../utils/configHelper');
const { investorOwnsInvestment } = require('./investmentAccess');
const { handleBookAppServiceCharge } = require('./investmentBookAppServiceCharge');
const {
  handleTraderActivateReservedInvestment,
  handleGetPoolInvestmentsForTrader,
  handleRecordPoolTradeParticipation,
  handleUpdatePoolTradeParticipation,
} = require('./investmentPoolTraderHandlers');
const { handleDiscoverTraders } = require('./investmentDiscoverTraders');
const { rollbackOrphanInvestmentAfterFailedReserve } = require('../utils/investmentReservationRollback');

Parse.Cloud.define('getInvestorPortfolio', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const query = new Parse.Query('Investment');
  query.equalTo('investorId', user.id);
  query.containedIn('status', ['active', 'executing']);

  const investments = await query.find({ useMasterKey: true });

  let totalInvested = 0;
  let totalCurrentValue = 0;
  let totalProfit = 0;

  const portfolio = investments.map(inv => {
    totalInvested += inv.get('amount') || 0;
    totalCurrentValue += inv.get('currentValue') || 0;
    totalProfit += inv.get('profit') || 0;
    return inv.toJSON();
  });

  return {
    investments: portfolio,
    summary: {
      totalInvested,
      totalCurrentValue,
      totalProfit,
      totalReturn: totalInvested > 0 ? (totalProfit / totalInvested) * 100 : 0,
      activeCount: investments.length,
    },
  };
});

Parse.Cloud.define('createInvestment', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const { traderId, amount } = request.params;

  if (!traderId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Trader-ID erforderlich.');

  const limitCheck = await validateInvestmentAmountAgainstLimits(amount);
  if (!limitCheck.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, limitCheck.error);
  }

  const traderQuery = new Parse.Query(Parse.User);
  traderQuery.equalTo('objectId', traderId);
  traderQuery.equalTo('role', 'trader');
  traderQuery.equalTo('status', 'active');
  const trader = await traderQuery.first({ useMasterKey: true });

  if (!trader) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trader nicht gefunden oder nicht aktiv.');

  const investorAccountType = user.get('accountType') || 'individual';
  const configuredChargeRate = await getAppServiceChargeRateForAccountType(investorAccountType);
  const grossCharge = round2(amount * configuredChargeRate);
  const serviceChargeTotal = round2(grossCharge);
  const required = round2(amount + serviceChargeTotal);

  try {
    const balanceResult = await Parse.Cloud.run('getWalletBalance', {}, { sessionToken: user.getSessionToken() });
    if (balanceResult && typeof balanceResult.balance === 'number' && balanceResult.balance < required) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        `Unzureichendes Guthaben (benötigt ${required.toFixed(2)} € für Investment + App Service Charge, verfügbar ${Number(balanceResult.balance).toFixed(2)} €).`,
      );
    }
  } catch (err) {
    if (err instanceof Parse.Error && err.code === Parse.Error.OPERATION_FORBIDDEN
        && typeof err.message === 'string' && err.message.startsWith('Unzureichendes Guthaben')) {
      throw err;
    }
    console.warn(`createInvestment: wallet balance check skipped (${err && err.message || err}); relying on client-side validation.`);
  }

  const Investment = Parse.Object.extend('Investment');
  const investment = new Investment();
  investment.set('investorId', user.id);
  investment.set('traderId', traderId);
  investment.set('amount', amount);

  await investment.save(null, { useMasterKey: true });

  // Idempotent: afterSave hat bookReserve bereits ausgeführt; bei Race/Retry sicherstellen.
  let reserveCheck;
  try {
    reserveCheck = await investmentEscrow.bookReserve({
      investorId: user.id,
      amount: round2(amount),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
      parseInvestment: investment,
    });
  } catch (err) {
    await rollbackOrphanInvestmentAfterFailedReserve(investment.id, err.message);
    throw err;
  }
  if (reserveCheck && reserveCheck.ok === false) {
    await rollbackOrphanInvestmentAfterFailedReserve(investment.id, reserveCheck.reason || 'unknown');
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Kundenguthaben-Reservierung fehlgeschlagen: ${reserveCheck.reason || 'unknown'}`,
    );
  }

  return {
    investmentId: investment.id,
    investmentNumber: investment.get('investmentNumber'),
    status: investment.get('status'),
  };
});

Parse.Cloud.define('confirmInvestment', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const { investmentId } = request.params;

  const Investment = Parse.Object.extend('Investment');
  const query = new Parse.Query(Investment);
  query.equalTo('investorId', user.id);
  const investment = await query.get(investmentId, { useMasterKey: true });

  if (investment.get('status') !== 'reserved') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Dieses Investment kann nicht bestätigt werden.');
  }

  const confirmAmount = investment.get('amount') || 0;
  const serviceChargeTotalStored = investment.get('serviceChargeTotal') || 0;
  const confirmRequired = round2(confirmAmount + serviceChargeTotalStored);
  try {
    const confirmBalance = await Parse.Cloud.run('getWalletBalance', {}, { sessionToken: user.getSessionToken() });
    if (confirmBalance && typeof confirmBalance.balance === 'number' && confirmBalance.balance < confirmRequired) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        `Unzureichendes Guthaben bei Aktivierung (benötigt ${confirmRequired.toFixed(2)} €, verfügbar ${Number(confirmBalance.balance).toFixed(2)} €).`,
      );
    }
  } catch (err) {
    if (err instanceof Parse.Error && err.code === Parse.Error.OPERATION_FORBIDDEN
        && typeof err.message === 'string' && err.message.startsWith('Unzureichendes Guthaben')) {
      throw err;
    }
    console.warn(`confirmInvestment: wallet balance re-check skipped ${investment.id} (${err && err.message || err}).`);
  }

  investment.set('status', 'active');
  investment.set('reservationStatus', 'active');
  await investment.save(null, { useMasterKey: true });

  try {
    await investmentEscrow.bookDeployToTrading({
      investorId: investment.get('investorId'),
      amount: round2(investment.get('amount') || 0),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
      businessCaseId: String(investment.get('businessCaseId') || '').trim(),
    });
  } catch (err) {
    console.error(`❌ bookDeployToTrading (confirmInvestment) idempotent repair ${investment.id}:`, err.message);
  }

  return { success: true, status: 'active' };
});

Parse.Cloud.define('cancelReservedInvestment', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const { investmentId } = request.params || {};
  if (!investmentId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „investmentId“ erforderlich.');

  const Investment = Parse.Object.extend('Investment');
  let investment;
  try {
    investment = await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });
  } catch {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Investment nicht gefunden.');
  }

  if (!investorOwnsInvestment(investment, user)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Vorgang nicht erlaubt.');
  }

  if (investment.get('status') !== 'reserved') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Nur reservierte Investments können storniert werden.');
  }

  investment.set('status', 'cancelled');
  await investment.save(null, { useMasterKey: true });

  return { success: true, investmentId: investment.id, status: 'cancelled' };
});

Parse.Cloud.define('bookAppServiceCharge', handleBookAppServiceCharge);

Parse.Cloud.define('traderActivateReservedInvestment', handleTraderActivateReservedInvestment);

Parse.Cloud.define('getPoolInvestmentsForTrader', handleGetPoolInvestmentsForTrader);

Parse.Cloud.define('recordPoolTradeParticipation', handleRecordPoolTradeParticipation);

Parse.Cloud.define('updatePoolTradeParticipation', handleUpdatePoolTradeParticipation);

Parse.Cloud.define('discoverTraders', handleDiscoverTraders);
