// ============================================================================
// Parse Cloud Code
// functions/investment.js - Investment Functions
// ============================================================================

'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { validateInvestmentAmountAgainstLimits } = require('../utils/investmentLimitsValidation');

/**
 * Match Investment.investorId to session user (objectId or stableId / email pattern).
 */
function investorOwnsInvestment(investment, user) {
  const invId = investment.get('investorId');
  if (!invId || !user) return false;
  const email = (user.get('email') || user.get('username') || '').toLowerCase();
  const stable = user.get('stableId') || (email ? `user:${email}` : '');
  return invId === user.id || (!!stable && invId === stable) || (!!email && invId === email);
}

/** Investment.traderId may be Parse _User id or stable id string used by the app. */
function traderOwnsInvestment(investment, user) {
  const tid = investment.get('traderId');
  if (!tid || !user) return false;
  if (tid === user.id) return true;
  const email = (user.get('email') || user.get('username') || '').toLowerCase();
  const stable = user.get('stableId') || (email ? `user:${email}` : '');
  return (!!stable && tid === stable) || (!!email && tid === email);
}

// Get investor portfolio
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
      activeCount: investments.length
    }
  };
});

// Create investment
Parse.Cloud.define('createInvestment', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const { traderId, amount } = request.params;

  if (!traderId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Trader-ID erforderlich.');

  const limitCheck = await validateInvestmentAmountAgainstLimits(amount);
  if (!limitCheck.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, limitCheck.error);
  }

  // Verify trader exists and is active
  const traderQuery = new Parse.Query(Parse.User);
  traderQuery.equalTo('objectId', traderId);
  traderQuery.equalTo('role', 'trader');
  traderQuery.equalTo('status', 'active');
  const trader = await traderQuery.first({ useMasterKey: true });

  if (!trader) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trader nicht gefunden oder nicht aktiv.');

  // Check balance
  const balanceResult = await Parse.Cloud.run('getWalletBalance', {}, { sessionToken: user.getSessionToken() });
  if (balanceResult.balance < amount) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Unzureichendes Guthaben.');
  }

  // Create investment
  const Investment = Parse.Object.extend('Investment');
  const investment = new Investment();
  investment.set('investorId', user.id);
  investment.set('traderId', traderId);
  investment.set('amount', amount);

  await investment.save(null, { useMasterKey: true });

  return {
    investmentId: investment.id,
    investmentNumber: investment.get('investmentNumber'),
    status: investment.get('status')
  };
});

// Confirm investment (activate)
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

  investment.set('status', 'active');
  await investment.save(null, { useMasterKey: true });

  try {
    await investmentEscrow.bookDeployToTrading({
      investorId: investment.get('investorId'),
      amount: round2(investment.get('amount') || 0),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
    });
  } catch (err) {
    console.error(`❌ bookDeployToTrading (confirmInvestment) idempotent repair ${investment.id}:`, err.message);
  }

  return { success: true, status: 'active' };
});

// Cancel reserved split investment (server SoT: escrow + wallet via trigger)
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

/**
 * Trader pool: when a buy uses reserved client capital, move Parse status reserved → active.
 * Runs afterSave Investment → escrow RSV→TRD + wallet/statement (same as confirmInvestment for investors).
 */
Parse.Cloud.define('traderActivateReservedInvestment', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');

  const role = user.get('role');
  if (role !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader-Rolle erforderlich.');
  }

  const { investmentId } = request.params || {};
  if (!investmentId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „investmentId“ erforderlich.');

  const Investment = Parse.Object.extend('Investment');
  let investment;
  try {
    investment = await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });
  } catch {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Investment nicht gefunden.');
  }

  if (!traderOwnsInvestment(investment, user)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Vorgang nicht erlaubt.');
  }

  if (investment.get('status') !== 'reserved') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Nur reservierte Investments können aktiviert werden.');
  }

  investment.set('status', 'active');
  await investment.save(null, { useMasterKey: true });

  try {
    await investmentEscrow.bookDeployToTrading({
      investorId: investment.get('investorId'),
      amount: round2(investment.get('amount') || 0),
      investmentId: investment.id,
      investmentNumber: investment.get('investmentNumber') || '',
    });
  } catch (err) {
    console.error(`❌ bookDeployToTrading (traderActivate) idempotent repair ${investment.id}:`, err.message);
  }

  return { success: true, investmentId: investment.id, status: 'active' };
});

/**
 * Trader session: list Investments where traderId matches (same id as on Investment rows, often MockTrader UUID).
 * Used to hydrate the trader app before pool activation on buy. Caller must be role trader.
 */
Parse.Cloud.define('getPoolInvestmentsForTrader', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  if (user.get('role') !== 'trader') {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Trader-Rolle erforderlich.');
  }

  const { traderId } = request.params || {};
  if (!traderId || typeof traderId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Parameter „traderId“ erforderlich.');
  }

  const q = new Parse.Query('Investment');
  q.equalTo('traderId', traderId);
  q.descending('createdAt');
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });

  return {
    results: rows.map((r) => r.toJSON()),
  };
});

// Get trader list for discovery
Parse.Cloud.define('discoverTraders', async (request) => {
  const { minRiskClass, maxRiskClass, limit = 20, skip = 0 } = request.params;

  const query = new Parse.Query(Parse.User);
  query.equalTo('role', 'trader');
  query.equalTo('status', 'active');
  query.equalTo('kycStatus', 'verified');
  query.limit(limit);
  query.skip(skip);

  const traders = await query.find({ useMasterKey: true });

  const result = [];
  for (const trader of traders) {
    // Get profile
    const profileQuery = new Parse.Query('UserProfile');
    profileQuery.equalTo('userId', trader.id);
    const profile = await profileQuery.first({ useMasterKey: true });

    // Get risk assessment
    const riskQuery = new Parse.Query('UserRiskAssessment');
    riskQuery.equalTo('userId', trader.id);
    riskQuery.descending('validFrom');
    const risk = await riskQuery.first({ useMasterKey: true });

    // Get investment stats
    const invQuery = new Parse.Query('Investment');
    invQuery.equalTo('traderId', trader.id);
    invQuery.equalTo('status', 'active');
    const activeInvestments = await invQuery.find({ useMasterKey: true });

    let totalAUM = 0;
    activeInvestments.forEach(inv => totalAUM += inv.get('amount') || 0);

    result.push({
      traderId: trader.id,
      displayName: profile ? `${profile.get('firstName')} ${profile.get('lastName').charAt(0)}.` : 'Trader',
      riskClass: risk ? risk.get('riskClass') : null,
      investorCount: activeInvestments.length,
      totalAUM,
      acceptingInvestments: totalAUM < 1000000 // Max pool size
    });
  }

  return { traders: result, total: result.length };
});
