'use strict';

async function findInvestment(investmentId, participation, trade) {
  const Investment = Parse.Object.extend('Investment');

  try {
    return await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });
  } catch (_) { /* not a Parse objectId */ }

  const byBatchId = await new Parse.Query(Investment)
    .equalTo('batchId', investmentId).first({ useMasterKey: true });
  if (byBatchId) {
    console.log(`  📊 Found investment via batchId: ${byBatchId.id}`);
    return byBatchId;
  }

  const investorId = participation.get('investorId');
  if (investorId) {
    const byInvestor = await new Parse.Query(Investment)
      .equalTo('investorId', investorId).descending('createdAt').first({ useMasterKey: true });
    if (byInvestor) {
      console.log(`  📊 Found investment via investorId: ${byInvestor.id}`);
      return byInvestor;
    }
  }

  const partCreated = participation.get('createdAt') || participation.createdAt;
  if (partCreated) {
    const windowStart = new Date(partCreated.getTime() - 60000);
    const windowEnd = new Date(partCreated.getTime() + 60000);
    const timeQuery = new Parse.Query(Investment);
    timeQuery.greaterThanOrEqualTo('createdAt', windowStart);
    timeQuery.lessThanOrEqualTo('createdAt', windowEnd);
    timeQuery.ascending('createdAt');
    const candidates = await timeQuery.find({ useMasterKey: true });
    if (candidates.length >= 1) {
      console.log(`  📊 Found investment via time-proximity: ${candidates[0].id}`);
      return candidates[0];
    }
  }

  if (trade) {
    const traderId = trade.get('traderId');
    const traderEmail = (traderId && traderId.startsWith('user:')) ? traderId.replace('user:', '') : null;
    if (traderEmail) {
      const traderUser = await new Parse.Query(Parse.User)
        .equalTo('email', traderEmail).first({ useMasterKey: true });
      if (traderUser) {
        const q1 = new Parse.Query(Investment).equalTo('traderId', traderUser.id);
        const q2 = new Parse.Query(Investment).equalTo('traderId', `user:${traderEmail}`);
        const inv = await Parse.Query.or(q1, q2).descending('createdAt').first({ useMasterKey: true });
        if (inv) {
          console.log(`  📊 Found investment via trader lookup: ${inv.id}`);
          return inv;
        }
      }
    }

    const tradeCreated = trade.get('createdAt') || trade.createdAt;
    if (tradeCreated) {
      const recent = await new Parse.Query(Investment)
        .greaterThanOrEqualTo('createdAt', new Date(tradeCreated.getTime() - 120000))
        .lessThanOrEqualTo('createdAt', new Date(tradeCreated.getTime() + 120000))
        .ascending('createdAt').first({ useMasterKey: true });
      if (recent) {
        console.log(`  📊 Found investment via trade-time proximity: ${recent.id}`);
        return recent;
      }
    }
  }

  return null;
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

async function findInvestmentsForTradeFallback(traderId) {
  const Investment = Parse.Object.extend('Investment');
  const statusFilter = ['active', 'executing', 'reserved'];
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
      // ignore best-effort lookup failures
    }
  }

  if (email) {
    const qStable = new Parse.Query(Investment);
    qStable.equalTo('traderId', `user:${email}`);
    qStable.containedIn('status', statusFilter);
    queries.push(qStable);
  }
  if (username) {
    const qUser = new Parse.Query(Investment);
    qUser.equalTo('traderId', username);
    qUser.containedIn('status', statusFilter);
    queries.push(qUser);

    const qName = new Parse.Query(Investment);
    qName.matches('traderName', username, 'i');
    qName.containedIn('status', statusFilter);
    queries.push(qName);
  }

  const nameHints = await resolveTraderNameHints(traderId);
  for (const hint of nameHints) {
    const qProfileName = new Parse.Query(Investment);
    qProfileName.matches('traderName', hint, 'i');
    qProfileName.containedIn('status', statusFilter);
    queries.push(qProfileName);
  }

  const rows = queries.length === 1
    ? await queries[0].find({ useMasterKey: true })
    : await Parse.Query.or(...queries).find({ useMasterKey: true });

  const unique = new Map();
  for (const row of rows) unique.set(row.id, row);
  return Array.from(unique.values()).sort((a, b) => a.createdAt - b.createdAt);
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

async function ensureParticipationsForTrade(trade) {
  const tradeId = trade.id;
  const tradeNumber = trade.get('tradeNumber');
  const traderId = String(trade.get('traderId') || '');
  const buyOrder = trade.get('buyOrder') || {};
  const buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);
  if (!tradeId || !traderId || !Number.isFinite(buyAmount) || buyAmount <= 0) {
    return [];
  }

  const investments = await findInvestmentsForTradeFallback(traderId);
  if (!investments.length) {
    console.log(`ℹ️ Trade #${tradeNumber}: participation fallback found no candidate investments`);
    return [];
  }

  const selected = await selectOneSplitPerInvestorForTrade(investments, tradeId);
  if (!selected.length) return [];

  let totalPool = 0;
  for (const inv of selected) {
    totalPool += Number(inv.get('currentValue') || inv.get('amount') || 0);
  }
  if (!Number.isFinite(totalPool) || totalPool <= 0) return [];

  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');
  const created = [];

  for (const inv of selected) {
    if (inv.get('status') === 'reserved') {
      inv.set('status', 'active');
      inv.set('reservationStatus', 'active');
      await inv.save(null, { useMasterKey: true });
    }

    const invValue = Number(inv.get('currentValue') || inv.get('amount') || 0);
    const ownershipPct = totalPool > 0 ? (invValue / totalPool) * 100 : 0;
    const allocatedAmount = buyAmount * (ownershipPct / 100);

    const p = new PoolParticipation();
    p.set('investmentId', inv.id);
    p.set('tradeId', tradeId);
    p.set('allocatedAmount', allocatedAmount);
    p.set('ownershipPercentage', ownershipPct);
    p.set('isSettled', false);
    await p.save(null, { useMasterKey: true });
    created.push(p);
  }

  console.log(`✅ Trade #${tradeNumber}: fallback created ${created.length} PoolTradeParticipation row(s)`);
  return created;
}

module.exports = {
  ensureParticipationsForTrade,
  findInvestment,
};
