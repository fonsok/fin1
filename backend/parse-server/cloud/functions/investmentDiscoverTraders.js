'use strict';

async function handleDiscoverTraders(request) {
  const { minRiskClass, maxRiskClass, limit = 20, skip = 0 } = request.params || {};

  const query = new Parse.Query(Parse.User);
  query.equalTo('role', 'trader');
  query.equalTo('status', 'active');
  query.equalTo('kycStatus', 'verified');
  query.limit(limit);
  query.skip(skip);

  const traders = await query.find({ useMasterKey: true });

  const result = [];
  for (const trader of traders) {
    const profileQuery = new Parse.Query('UserProfile');
    profileQuery.equalTo('userId', trader.id);
    const profile = await profileQuery.first({ useMasterKey: true });

    const riskQuery = new Parse.Query('UserRiskAssessment');
    riskQuery.equalTo('userId', trader.id);
    riskQuery.descending('validFrom');
    const risk = await riskQuery.first({ useMasterKey: true });

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
      acceptingInvestments: totalAUM < 1000000,
    });
  }

  return { traders: result, total: result.length };
}

module.exports = {
  handleDiscoverTraders,
};
