// ============================================================================
// Parse Cloud Code
// functions/investment.js - Investment Functions
// ============================================================================

'use strict';

// Get investor portfolio
Parse.Cloud.define('getInvestorPortfolio', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

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
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { traderId, amount } = request.params;

  if (!traderId) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Trader ID required');
  if (!amount || amount < 100) throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Minimum investment €100');

  // Verify trader exists and is active
  const traderQuery = new Parse.Query(Parse.User);
  traderQuery.equalTo('objectId', traderId);
  traderQuery.equalTo('role', 'trader');
  traderQuery.equalTo('status', 'active');
  const trader = await traderQuery.first({ useMasterKey: true });

  if (!trader) throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trader not found');

  // Check balance
  const balanceResult = await Parse.Cloud.run('getWalletBalance', {}, { sessionToken: user.getSessionToken() });
  if (balanceResult.balance < amount) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Insufficient balance');
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
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');

  const { investmentId } = request.params;

  const Investment = Parse.Object.extend('Investment');
  const query = new Parse.Query(Investment);
  query.equalTo('investorId', user.id);
  const investment = await query.get(investmentId, { useMasterKey: true });

  if (investment.get('status') !== 'reserved') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Investment cannot be confirmed');
  }

  investment.set('status', 'active');
  await investment.save(null, { useMasterKey: true });

  return { success: true, status: 'active' };
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
