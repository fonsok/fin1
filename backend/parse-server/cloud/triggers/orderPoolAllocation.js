'use strict';

const investmentEscrow = require('../utils/accountingHelper/investmentEscrow');
const { round2 } = require('../utils/accountingHelper/shared');

async function allocateTradeToInvestmentPools(trade) {
  const traderId = trade.get('traderId');
  const tradeAmount = trade.get('buyAmount');

  const Investment = Parse.Object.extend('Investment');
  const query = new Parse.Query(Investment);
  query.equalTo('traderId', traderId);
  query.containedIn('status', ['reserved', 'active', 'executing']);

  let investments = await query.find({ useMasterKey: true });

  if (investments.length === 0 && traderId) {
    const fallbackQueries = [];
    const qExact = new Parse.Query(Investment);
    qExact.equalTo('traderId', traderId);
    qExact.containedIn('status', ['reserved', 'active', 'executing']);
    fallbackQueries.push(qExact);

    let email = null;
    let username = null;
    if (String(traderId).startsWith('user:')) {
      email = String(traderId).replace('user:', '');
      username = email.split('@')[0];
    } else {
      try {
        const traderUser = await new Parse.Query(Parse.User).get(traderId, { useMasterKey: true });
        email = traderUser.get('email') || null;
        username = traderUser.get('username') || (email ? String(email).split('@')[0] : null);
      } catch (_) {
        void _;
      }
    }

    if (email) {
      const qUserEmail = new Parse.Query(Investment);
      qUserEmail.equalTo('traderId', `user:${email}`);
      qUserEmail.containedIn('status', ['reserved', 'active', 'executing']);
      fallbackQueries.push(qUserEmail);

      const qPlainEmail = new Parse.Query(Investment);
      qPlainEmail.equalTo('traderId', email);
      qPlainEmail.containedIn('status', ['reserved', 'active', 'executing']);
      fallbackQueries.push(qPlainEmail);
    }

    if (username) {
      const qUsername = new Parse.Query(Investment);
      qUsername.equalTo('traderId', username);
      qUsername.containedIn('status', ['reserved', 'active', 'executing']);
      fallbackQueries.push(qUsername);
    }

    investments = await Parse.Query.or(...fallbackQueries).find({ useMasterKey: true });
  }

  if (investments.length === 0) return;

  let totalPool = 0;
  for (const inv of investments) {
    totalPool += inv.get('currentValue') || inv.get('amount') || 0;
  }

  if (totalPool === 0) return;

  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');

  for (const investment of investments) {
    const dupPart = await new Parse.Query(PoolParticipation)
      .equalTo('tradeId', trade.id)
      .equalTo('investmentId', investment.id)
      .first({ useMasterKey: true });
    if (dupPart) {
      continue;
    }

    if (investment.get('status') === 'reserved') {
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
        console.error(`allocateTradeToInvestmentPools bookDeploy ${investment.id}:`, err.message);
      }
    }

    const invValue = investment.get('currentValue') || investment.get('amount') || 0;
    const ownershipPct = (invValue / totalPool) * 100;
    const allocatedAmount = tradeAmount * (ownershipPct / 100);

    const participation = new PoolParticipation();
    participation.set('investmentId', investment.id);
    participation.set('tradeId', trade.id);
    participation.set('allocatedAmount', allocatedAmount);
    participation.set('ownershipPercentage', ownershipPct);
    participation.set('isSettled', false);

    await participation.save(null, { useMasterKey: true });
  }
}

module.exports = {
  allocateTradeToInvestmentPools,
};
