'use strict';

const { pickUserDisplayName } = require('../../../utils/traderDisplayNameForBeleg');
const { tradeListEconomicsFromParseTrade } = require('../../../utils/accountingHelper/legPriceMetrics');

/**
 * Distinct investor stableIds per trade from pool participation (SSOT).
 * Trade.investorIds is optional legacy; settlement never sets it today — without this,
 * Summary Report showed "0 Investoren" despite PoolTradeParticipation rows.
 */
async function loadDistinctInvestorIdsByTradeId(tradeRows) {
  const tradeIds = tradeRows.map((t) => t.id).filter(Boolean);
  if (tradeIds.length === 0) {
    return new Map();
  }

  const pq = new Parse.Query('PoolTradeParticipation');
  pq.containedIn('tradeId', tradeIds);
  pq.limit(5000);
  const parts = await pq.find({ useMasterKey: true });

  const investmentIdsByTrade = new Map();
  const allInvestmentIds = new Set();
  for (const p of parts) {
    const tid = p.get('tradeId');
    const iid = p.get('investmentId');
    if (!tid || !iid) continue;
    if (!investmentIdsByTrade.has(tid)) investmentIdsByTrade.set(tid, new Set());
    investmentIdsByTrade.get(tid).add(iid);
    allInvestmentIds.add(iid);
  }

  if (allInvestmentIds.size === 0) {
    return new Map();
  }

  const iq = new Parse.Query('Investment');
  iq.containedIn('objectId', Array.from(allInvestmentIds));
  iq.limit(5000);
  const investments = await iq.find({ useMasterKey: true });
  const investorByInvestmentId = new Map();
  for (const inv of investments) {
    const invId = inv.get('investorId');
    if (invId) investorByInvestmentId.set(inv.id, invId);
  }

  const out = new Map();
  for (const [tid, iidSet] of investmentIdsByTrade) {
    const uniq = new Set();
    for (const iid of iidSet) {
      const invStable = investorByInvestmentId.get(iid);
      if (invStable) uniq.add(invStable);
    }
    out.set(tid, Array.from(uniq));
  }
  return out;
}

async function loadTraderDisplayNamesByTraderId(traderIds) {
  const uniq = [...new Set(traderIds.map((id) => String(id || '').trim()).filter(Boolean))];
  const out = new Map();
  if (uniq.length === 0) return out;

  const objectIds = [];
  const legacyEmails = [];
  for (const id of uniq) {
    if (id.startsWith('user:')) legacyEmails.push(id.replace(/^user:/i, '').toLowerCase());
    else objectIds.push(id);
  }

  const users = [];
  if (objectIds.length > 0) {
    const idQ = new Parse.Query(Parse.User);
    idQ.containedIn('objectId', objectIds);
    idQ.limit(Math.min(objectIds.length, 500));
    users.push(...(await idQ.find({ useMasterKey: true })));
  }

  const foundIds = new Set(users.map((u) => u.id));
  const missingIds = objectIds.filter((id) => !foundIds.has(id));
  if (missingIds.length > 0) {
    const emailQ = new Parse.Query(Parse.User);
    emailQ.containedIn('email', missingIds.map((e) => e.toLowerCase()));
    emailQ.limit(Math.min(missingIds.length, 500));
    users.push(...(await emailQ.find({ useMasterKey: true })));
  }

  if (legacyEmails.length > 0) {
    const legQ = new Parse.Query(Parse.User);
    legQ.containedIn('email', legacyEmails);
    legQ.limit(Math.min(legacyEmails.length, 500));
    users.push(...(await legQ.find({ useMasterKey: true })));
  }

  const userIds = [...new Set(users.map((u) => u.id))];
  const profilesByUserId = new Map();
  if (userIds.length > 0) {
    const pq = new Parse.Query('UserProfile');
    pq.containedIn('userId', userIds);
    pq.limit(Math.min(userIds.length, 500));
    const profiles = await pq.find({ useMasterKey: true });
    for (const p of profiles) profilesByUserId.set(p.get('userId'), p);
  }

  const userById = new Map(users.map((u) => [u.id, u]));
  const userByEmail = new Map(
    users
      .filter((u) => u.get('email'))
      .map((u) => [String(u.get('email')).toLowerCase(), u]),
  );

  for (const tid of uniq) {
    let user = null;
    if (tid.startsWith('user:')) {
      user = userByEmail.get(tid.replace(/^user:/i, '').toLowerCase());
    } else {
      user = userById.get(tid) || userByEmail.get(tid.toLowerCase());
    }
    const name = user ? pickUserDisplayName(user, profilesByUserId.get(user.id)) : null;
    out.set(tid, name || tid);
  }
  return out;
}

async function loadTraderDisplayNamesForTrades(tradeRows) {
  const ids = tradeRows.map((t) => t.get('traderId')).filter(Boolean);
  return loadTraderDisplayNamesByTraderId(ids);
}

function mapTradeRow(trade, investorIdsFromPool = null, traderName = null, feeConfig = {}) {
  const buyOrder = trade.get('buyOrder') || {};
  const economics = tradeListEconomicsFromParseTrade(trade, feeConfig);
  const { buyAmount, sellAmount, profit, returnPercentage } = economics;

  const fromObject = trade.get('investorIds');
  const investorIds =
    Array.isArray(investorIdsFromPool) && investorIdsFromPool.length > 0
      ? investorIdsFromPool
      : (Array.isArray(fromObject) ? fromObject : []);

  return {
    tradeId: trade.id,
    tradeNumber: trade.get('tradeNumber') || 0,
    tradeNumberYear: trade.get('tradeNumberYear') || null,
    symbol: trade.get('symbol') || buyOrder.symbol || 'N/A',
    traderId: trade.get('traderId') || '',
    traderName: traderName || trade.get('traderName') || 'N/A',
    buyAmount,
    sellAmount,
    returnPercentage,
    profit,
    status: trade.get('status') || 'unknown',
    investorIds,
    createdAt: trade.get('createdAt'),
  };
}

module.exports = {
  loadDistinctInvestorIdsByTradeId,
  loadTraderDisplayNamesByTraderId,
  loadTraderDisplayNamesForTrades,
  mapTradeRow,
};
