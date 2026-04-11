'use strict';

function registerTradesDebugFunctions() {
  Parse.Cloud.define('getTradesWithInvestors', async () => {
    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.descending('tradeNumber');
    tradeQuery.limit(10);
    const trades = await tradeQuery.find({ useMasterKey: true });

    const result = await Promise.all(trades.map(async (trade) => {
      const participationQuery = new Parse.Query('PoolTradeParticipation');
      participationQuery.equalTo('tradeId', trade.id);
      const participations = await participationQuery.find({ useMasterKey: true });

      return {
        objectId: trade.id,
        tradeNumber: trade.get('tradeNumber'),
        symbol: trade.get('symbol'),
        description: trade.get('description'),
        status: trade.get('status'),
        grossProfit: trade.get('grossProfit'),
        totalFees: trade.get('totalFees'),
        traderId: trade.get('traderId'),
        createdAt: trade.get('createdAt'),
        completedAt: trade.get('completedAt'),
        investors: participations.map((p) => ({
          investorId: p.get('investorId'),
          investorName: p.get('investorName'),
          ownershipPercentage: p.get('ownershipPercentage'),
          investedAmount: p.get('allocatedAmount'),
          profitShare: p.get('profitShare'),
          isSettled: p.get('isSettled'),
        })),
      };
    }));

    return { trades: result };
  });

  Parse.Cloud.define('createTestPoolParticipations', async () => {
    console.log('📊 Creating test PoolTradeParticipations...');

    const tradeQuery = new Parse.Query('Trade');
    tradeQuery.descending('tradeNumber');
    tradeQuery.limit(5);
    const trades = await tradeQuery.find({ useMasterKey: true });

    if (trades.length === 0) {
      return { success: false, message: 'No trades found' };
    }

    const created = [];
    const testInvestors = [
      { id: 'user:investor1@test.com', name: 'Investor One' },
      { id: 'user:investor2@test.com', name: 'Investor Two' },
    ];

    for (const trade of trades) {
      const tradeId = trade.id;
      const traderId = trade.get('traderId');
      const buyOrder = trade.get('buyOrder') || {};
      const totalAmount = buyOrder.totalAmount || 10000;
      const grossProfit = trade.get('grossProfit') || 0;

      for (let i = 0; i < testInvestors.length; i += 1) {
        const investor = testInvestors[i];
        const ownershipPct = i === 0 ? 0.40 : 0.35;
        const allocatedAmount = totalAmount * ownershipPct;
        const profitShare = grossProfit * ownershipPct;

        const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');
        const participation = new PoolParticipation();

        participation.set('tradeId', tradeId);
        participation.set('investmentId', `inv-test-${trade.get('tradeNumber')}-${i + 1}`);
        participation.set('investorId', investor.id);
        participation.set('investorName', investor.name);
        participation.set('traderId', traderId);
        participation.set('poolReservationId', `pool-res-${trade.get('tradeNumber')}-${i + 1}`);
        participation.set('poolNumber', i + 1);
        participation.set('allocatedAmount', allocatedAmount);
        participation.set('totalTradeValue', totalAmount);
        participation.set('ownershipPercentage', ownershipPct);
        participation.set('profitShare', profitShare);
        participation.set('isSettled', trade.get('status') === 'completed');

        await participation.save(null, { useMasterKey: true });
        created.push({
          tradeNumber: trade.get('tradeNumber'),
          investor: investor.name,
          ownershipPct: `${(ownershipPct * 100).toFixed(0)}%`,
          profitShare: profitShare.toFixed(2),
        });
      }
    }

    console.log(`✅ Created ${created.length} test participations`);
    return {
      success: true,
      message: `Created ${created.length} participations for ${trades.length} trades`,
      participations: created,
    };
  });
}

module.exports = { registerTradesDebugFunctions };
