'use strict';

async function resolveTraderUser(traderId) {
  if (!traderId) return null;
  if (traderId.startsWith('user:')) {
    const email = traderId.replace('user:', '');
    return await new Parse.Query(Parse.User)
      .equalTo('email', email)
      .first({ useMasterKey: true });
  }
  try {
    return await new Parse.Query(Parse.User).get(traderId, { useMasterKey: true });
  } catch (_) {
    return await new Parse.Query(Parse.User)
      .equalTo('email', traderId)
      .first({ useMasterKey: true });
  }
}

async function resolveTraderNameHints(traderId) {
  try {
    const traderUser = await resolveTraderUser(traderId);
    if (!traderUser) return [];

    const profile = await new Parse.Query('UserProfile')
      .equalTo('userId', traderUser.id)
      .first({ useMasterKey: true });

    const firstName = String(profile?.get('firstName') || traderUser.get('firstName') || '').trim();
    const lastName = String(profile?.get('lastName') || traderUser.get('lastName') || '').trim();
    const fullName = `${firstName} ${lastName}`.trim();
    return [fullName, firstName, lastName].filter(Boolean);
  } catch (_) {
    return [];
  }
}

async function findTraderInvestmentsForActivation(traderId) {
  const statusFilter = ['reserved', 'active', 'executing'];
  const Investment = Parse.Object.extend('Investment');
  const queries = [];

  const qExact = new Parse.Query(Investment);
  qExact.equalTo('traderId', traderId);
  qExact.containedIn('status', statusFilter);
  queries.push(qExact);

  let email = null;
  let username = null;
  if (traderId.startsWith('user:')) {
    email = traderId.replace('user:', '');
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
    qUserEmail.containedIn('status', statusFilter);
    queries.push(qUserEmail);

    const qPlainEmail = new Parse.Query(Investment);
    qPlainEmail.equalTo('traderId', email);
    qPlainEmail.containedIn('status', statusFilter);
    queries.push(qPlainEmail);
  }

  if (username) {
    const qUsername = new Parse.Query(Investment);
    qUsername.equalTo('traderId', username);
    qUsername.containedIn('status', statusFilter);
    queries.push(qUsername);
  }

  const nameHints = await resolveTraderNameHints(traderId);
  for (const hint of nameHints) {
    const qName = new Parse.Query(Investment);
    qName.matches('traderName', hint, 'i');
    qName.containedIn('status', statusFilter);
    queries.push(qName);
  }

  const rows = queries.length === 1
    ? await queries[0].find({ useMasterKey: true })
    : await Parse.Query.or(...queries).find({ useMasterKey: true });

  const unique = new Map();
  for (const row of rows) unique.set(row.id, row);
  return Array.from(unique.values()).sort((a, b) => a.createdAt - b.createdAt);
}

async function hasOpenParticipationOnOtherTrade(investmentId, tradeId) {
  const q = new Parse.Query('PoolTradeParticipation');
  q.equalTo('investmentId', investmentId);
  q.equalTo('isSettled', false);
  q.notEqualTo('tradeId', tradeId);
  const existing = await q.first({ useMasterKey: true });
  return Boolean(existing);
}

function sortInvestmentSplits(a, b) {
  const seqA = Number.isFinite(a.get('sequenceNumber')) ? Number(a.get('sequenceNumber')) : Number.MAX_SAFE_INTEGER;
  const seqB = Number.isFinite(b.get('sequenceNumber')) ? Number(b.get('sequenceNumber')) : Number.MAX_SAFE_INTEGER;
  if (seqA !== seqB) return seqA - seqB;
  return a.createdAt - b.createdAt;
}

async function selectOneSplitPerInvestorForTrade(investments, tradeId) {
  const byInvestor = new Map();
  for (const inv of investments) {
    const investorId = String(inv.get('investorId') || '').trim();
    if (!investorId) continue;
    if (!byInvestor.has(investorId)) byInvestor.set(investorId, []);
    byInvestor.get(investorId).push(inv);
  }

  const selected = [];
  for (const splits of byInvestor.values()) {
    const sorted = [...splits].sort(sortInvestmentSplits);
    let chosen = null;
    for (const inv of sorted) {
      const status = String(inv.get('status') || '');
      if (!['reserved', 'active', 'executing'].includes(status)) continue;
      // eslint-disable-next-line no-await-in-loop
      const inUse = await hasOpenParticipationOnOtherTrade(inv.id, tradeId);
      if (inUse) continue;
      chosen = inv;
      break;
    }
    if (chosen) selected.push(chosen);
  }
  return selected;
}

async function ensurePoolActivationForNewTrade(trade) {
  const tradeId = trade.id;
  if (!tradeId) return;

  const existingParticipation = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .first({ useMasterKey: true });
  if (existingParticipation) return;

  const buyOrder = trade.get('buyOrder') || {};
  const buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);
  if (!Number.isFinite(buyAmount) || buyAmount <= 0) return;

  const traderId = String(trade.get('traderId') || '');
  if (!traderId) return;

  const investments = await findTraderInvestmentsForActivation(traderId);
  if (!investments.length) {
    console.log(`ℹ️ Trade #${trade.get('tradeNumber')}: no candidate investments for traderId=${traderId}`);
    return;
  }

  const selected = await selectOneSplitPerInvestorForTrade(investments, tradeId);
  if (!selected.length) return;

  let totalPool = 0;
  for (const inv of selected) {
    totalPool += Number(inv.get('currentValue') || inv.get('amount') || 0);
  }
  if (!Number.isFinite(totalPool) || totalPool <= 0) return;

  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');

  for (const inv of selected) {
    if (inv.get('status') === 'reserved') {
      inv.set('status', 'active');
      inv.set('reservationStatus', 'active');
      await inv.save(null, { useMasterKey: true });
    }

    const invValue = Number(inv.get('currentValue') || inv.get('amount') || 0);
    const ownershipPct = totalPool > 0 ? (invValue / totalPool) * 100 : 0;
    const allocatedAmount = buyAmount * (ownershipPct / 100);

    const participation = new PoolParticipation();
    participation.set('investmentId', inv.id);
    participation.set('tradeId', tradeId);
    participation.set('allocatedAmount', allocatedAmount);
    participation.set('ownershipPercentage', ownershipPct);
    participation.set('isSettled', false);
    await participation.save(null, { useMasterKey: true });
  }

  console.log(`✅ Trade #${trade.get('tradeNumber')}: activated ${selected.length} investment(s) and created participations`);
}

module.exports = {
  ensurePoolActivationForNewTrade,
};
