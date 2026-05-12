'use strict';

async function findTestUserIds({ testEmailDomain, testUsernames }) {
  const usernameList = Array.isArray(testUsernames)
    ? testUsernames.map(String).map((s) => s.trim()).filter(Boolean)
    : [];

  const queries = [];

  if (usernameList.length) {
    const qUsernames = new Parse.Query(Parse.User);
    qUsernames.containedIn('username', usernameList);
    qUsernames.limit(1000);
    queries.push(qUsernames);
  }

  const domain = String(testEmailDomain || '').trim();
  if (domain) {
    const qEmail = new Parse.Query(Parse.User);
    qEmail.matches('email', `${domain.replace('.', '\\.')}$`, 'i');
    qEmail.limit(1000);
    queries.push(qEmail);
  }

  if (!queries.length) return [];

  const users = queries.length === 1
    ? await queries[0].find({ useMasterKey: true })
    : await Parse.Query.or(...queries).find({ useMasterKey: true });

  return users.map((u) => u.id);
}

/**
 * Resolves id lists for scoped wipe (null ids ⇒ full-table wipe handled by caller).
 */
async function collectTradingResetTargets({
  normalizedScope,
  sinceDate,
  testEmailDomain,
  testUserIdPrefix,
  testUsernames,
}) {
  if (normalizedScope === 'all') {
    return {
      tradeIds: null,
      orderIds: null,
      investmentIds: null,
      holdingIds: null,
      investmentBatchIds: null,
      userIds: null,
    };
  }

  if (normalizedScope === 'sinceHours' && sinceDate) {
    const trades = await new Parse.Query('Trade').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
    const orders = await new Parse.Query('Order').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
    const investments = await new Parse.Query('Investment').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
    const holdings = await new Parse.Query('Holding').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
    const batches = await new Parse.Query('InvestmentBatch').greaterThanOrEqualTo('createdAt', sinceDate).limit(1000).find({ useMasterKey: true });
    return {
      tradeIds: trades.map((t) => t.id),
      orderIds: orders.map((o) => o.id),
      investmentIds: investments.map((i) => i.id),
      holdingIds: holdings.map((h) => h.id),
      investmentBatchIds: batches.map((b) => b.id),
      userIds: null,
    };
  }

  const realUserIds = await findTestUserIds({ testEmailDomain, testUsernames });
  const usernameList = Array.isArray(testUsernames)
    ? testUsernames.map(String).map((s) => s.trim()).filter(Boolean)
    : [];

  const prefix = String(testUserIdPrefix || 'user:');

  const qTrade = new Parse.Query('Trade');
  qTrade.matches('traderId', `^${prefix}`, 'i');
  const qTrade2 = new Parse.Query('Trade');
  qTrade2.containedIn('traderId', realUserIds);
  const qTrade3 = new Parse.Query('Trade');
  if (usernameList.length) qTrade3.containedIn('traderId', usernameList);
  const trades = await Parse.Query.or(qTrade, qTrade2, qTrade3).limit(1000).find({ useMasterKey: true });

  const qOrder = new Parse.Query('Order');
  qOrder.matches('traderId', `^${prefix}`, 'i');
  const qOrder2 = new Parse.Query('Order');
  qOrder2.containedIn('traderId', realUserIds);
  const qOrder3 = new Parse.Query('Order');
  if (usernameList.length) qOrder3.containedIn('traderId', usernameList);
  const orders = await Parse.Query.or(qOrder, qOrder2, qOrder3).limit(1000).find({ useMasterKey: true });

  const qInv = new Parse.Query('Investment');
  qInv.matches('investorId', `^${prefix}`, 'i');
  const qInv2 = new Parse.Query('Investment');
  qInv2.containedIn('investorId', realUserIds);
  const qInv3 = new Parse.Query('Investment');
  if (usernameList.length) qInv3.containedIn('investorId', usernameList);
  const investments = await Parse.Query.or(qInv, qInv2, qInv3).limit(1000).find({ useMasterKey: true });

  const qHold = new Parse.Query('Holding');
  qHold.matches('traderId', `^${prefix}`, 'i');
  const qHold2 = new Parse.Query('Holding');
  qHold2.containedIn('traderId', realUserIds);
  const qHold3 = new Parse.Query('Holding');
  if (usernameList.length) qHold3.containedIn('traderId', usernameList);
  const holdings = await Parse.Query.or(qHold, qHold2, qHold3).limit(1000).find({ useMasterKey: true });

  const qBatch = new Parse.Query('InvestmentBatch');
  qBatch.matches('investorId', `^${prefix}`, 'i');
  const qBatch2 = new Parse.Query('InvestmentBatch');
  qBatch2.containedIn('investorId', realUserIds);
  const qBatch3 = new Parse.Query('InvestmentBatch');
  if (usernameList.length) qBatch3.containedIn('investorId', usernameList);
  const invBatches = await Parse.Query.or(qBatch, qBatch2, qBatch3).limit(1000).find({ useMasterKey: true });

  return {
    tradeIds: trades.map((t) => t.id),
    orderIds: orders.map((o) => o.id),
    investmentIds: investments.map((i) => i.id),
    holdingIds: holdings.map((h) => h.id),
    investmentBatchIds: invBatches.map((b) => b.id),
    userIds: realUserIds,
  };
}

module.exports = {
  collectTradingResetTargets,
};
