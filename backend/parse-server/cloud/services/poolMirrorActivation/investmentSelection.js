'use strict';

const MAX_INVESTMENTS_PER_ACTIVATION_QUERY = 2000;
const PARTICIPATION_LOOKUP_CHUNK = 100;

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
  qExact.limit(MAX_INVESTMENTS_PER_ACTIVATION_QUERY);
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
    qUserEmail.limit(MAX_INVESTMENTS_PER_ACTIVATION_QUERY);
    queries.push(qUserEmail);

    const qPlainEmail = new Parse.Query(Investment);
    qPlainEmail.equalTo('traderId', email);
    qPlainEmail.containedIn('status', statusFilter);
    qPlainEmail.limit(MAX_INVESTMENTS_PER_ACTIVATION_QUERY);
    queries.push(qPlainEmail);
  }

  if (username) {
    const qUsername = new Parse.Query(Investment);
    qUsername.equalTo('traderId', username);
    qUsername.containedIn('status', statusFilter);
    qUsername.limit(MAX_INVESTMENTS_PER_ACTIVATION_QUERY);
    queries.push(qUsername);
  }

  const nameHints = await resolveTraderNameHints(traderId);
  for (const hint of nameHints) {
    const qName = new Parse.Query(Investment);
    qName.matches('traderName', hint, 'i');
    qName.containedIn('status', statusFilter);
    qName.limit(MAX_INVESTMENTS_PER_ACTIVATION_QUERY);
    queries.push(qName);
  }

  const rows = queries.length === 1
    ? await queries[0].find({ useMasterKey: true })
    : await Parse.Query.or(...queries).limit(MAX_INVESTMENTS_PER_ACTIVATION_QUERY).find({ useMasterKey: true });

  const unique = new Map();
  for (const row of rows) unique.set(row.id, row);
  return Array.from(unique.values()).sort((a, b) => a.createdAt - b.createdAt);
}

/**
 * Investments with an open participation on a different trade (batched, indexed).
 * @returns {Promise<Set<string>>} investmentIds
 */
async function loadInvestmentIdsBlockedByOtherOpenTrade(investmentIds, tradeId) {
  const blocked = new Set();
  const ids = [...new Set(investmentIds.filter(Boolean))];
  if (!ids.length) return blocked;

  for (let offset = 0; offset < ids.length; offset += PARTICIPATION_LOOKUP_CHUNK) {
    const chunk = ids.slice(offset, offset + PARTICIPATION_LOOKUP_CHUNK);
    const q = new Parse.Query('PoolTradeParticipation');
    q.containedIn('investmentId', chunk);
    q.equalTo('isSettled', false);
    q.notEqualTo('tradeId', tradeId);
    q.select('investmentId');
    q.limit(10000);
    // eslint-disable-next-line no-await-in-loop
    const rows = await q.find({ useMasterKey: true });
    for (const row of rows) {
      const id = row.get('investmentId');
      if (id) blocked.add(id);
    }
  }
  return blocked;
}

async function hasOpenParticipationOnOtherTrade(investmentId, tradeId) {
  const blocked = await loadInvestmentIdsBlockedByOtherOpenTrade([investmentId], tradeId);
  return blocked.has(investmentId);
}

function sortInvestmentSplits(a, b) {
  const seqA = Number.isFinite(a.get('sequenceNumber')) ? Number(a.get('sequenceNumber')) : Number.MAX_SAFE_INTEGER;
  const seqB = Number.isFinite(b.get('sequenceNumber')) ? Number(b.get('sequenceNumber')) : Number.MAX_SAFE_INTEGER;
  if (seqA !== seqB) return seqA - seqB;
  return a.createdAt - b.createdAt;
}

async function selectOneSplitPerInvestorForTrade(investments, tradeId) {
  const blockedIds = await loadInvestmentIdsBlockedByOtherOpenTrade(
    investments.map((inv) => inv.id),
    tradeId,
  );

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
      if (blockedIds.has(inv.id)) continue;
      chosen = inv;
      break;
    }
    if (chosen) selected.push(chosen);
  }
  return selected;
}

module.exports = {
  findTraderInvestmentsForActivation,
  selectOneSplitPerInvestorForTrade,
  hasOpenParticipationOnOtherTrade,
  loadInvestmentIdsBlockedByOtherOpenTrade,
  MAX_INVESTMENTS_PER_ACTIVATION_QUERY,
};
