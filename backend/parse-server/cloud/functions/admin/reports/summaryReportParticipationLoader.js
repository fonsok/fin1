'use strict';

const { round2 } = require('../../../utils/accountingHelper/shared');
const {
  computeTradeLevelPoolBuyTotals,
  allocateProRataByInvestmentCapital,
} = require('../../../utils/poolMirrorEconomics/proRataAllocation');

async function loadParticipationsByPoolTradeIds(poolTradeIds) {
  const ids = [...new Set(poolTradeIds.filter(Boolean))];
  if (!ids.length) return new Map();

  const pq = new Parse.Query('PoolTradeParticipation');
  pq.containedIn('tradeId', ids);
  pq.limit(5000);
  const parts = await pq.find({ useMasterKey: true });

  const byTrade = new Map();
  const investmentIds = new Set();
  for (const p of parts) {
    const tid = p.get('tradeId');
    if (!tid) continue;
    if (!byTrade.has(tid)) byTrade.set(tid, []);
    byTrade.get(tid).push(p);
    const iid = p.get('investmentId');
    if (iid) investmentIds.add(iid);
  }

  const investmentById = new Map();
  if (investmentIds.size > 0) {
    const invRows = await new Parse.Query('Investment')
      .containedIn('objectId', Array.from(investmentIds))
      .limit(investmentIds.size)
      .find({ useMasterKey: true });
    for (const inv of invRows) investmentById.set(inv.id, inv);
  }

  const userIds = new Set();
  for (const inv of investmentById.values()) {
    const uid = inv.get('investorId');
    if (uid) userIds.add(uid);
  }
  const userById = new Map();
  if (userIds.size > 0) {
    const users = await new Parse.Query(Parse.User)
      .containedIn('objectId', Array.from(userIds))
      .limit(userIds.size)
      .find({ useMasterKey: true });
    for (const u of users) userById.set(u.id, u);
  }

  const enrichedByTrade = new Map();
  for (const [tid, partList] of byTrade) {
    enrichedByTrade.set(
      tid,
      partList.map((p) => mapParticipationRow(p, investmentById, userById)),
    );
  }
  return enrichedByTrade;
}

function mapParticipationRow(participation, investmentById, userById) {
  const investmentId = participation.get('investmentId') || '';
  const inv = investmentId ? investmentById.get(investmentId) : null;
  let investorId = participation.get('investorId') || inv?.get('investorId') || '';
  let investorEmail = '';
  let investorName = participation.get('investorName') || '';

  if (investorId && userById.has(investorId)) {
    const u = userById.get(investorId);
    investorEmail = u.get('email') || '';
    if (!investorName) {
      investorName = u.get('firstName')
        ? `${u.get('firstName')} ${u.get('lastName') || ''}`.trim()
        : investorEmail;
    }
  }
  if (investorEmail && investorEmail.startsWith('user:')) {
    investorEmail = investorEmail.replace('user:', '');
  }
  if (investorId && String(investorId).startsWith('user:')) {
    investorId = String(investorId).replace('user:', '');
  }

  const rawOwnership = Number(participation.get('ownershipPercentage') || 0);
  const ownershipPercentage = rawOwnership > 1 ? rawOwnership : rawOwnership * 100;
  const investmentStatus = String(inv?.get('status') || '').toLowerCase();
  const investmentCapital = round2(
    inv?.get('amount')
    || participation.get('allocatedAmount')
    || participation.get('investedAmount')
    || inv?.get('currentValue')
    || 0,
  );

  const buySnapshot = participation.get('buySnapshot') || null;

  return {
    investmentId,
    investmentNumber: inv?.get('investmentNumber') || '',
    investorId,
    investorName: investorName || investorEmail || '—',
    investorEmail,
    ownershipPercentage: round2(ownershipPercentage),
    investmentStatus,
    investmentCapital,
    allocatedAmount: round2(participation.get('allocatedAmount') || participation.get('investedAmount') || 0),
    profitShare: round2(participation.get('profitShare') || 0),
    commissionAmount: round2(participation.get('commissionAmount') || 0),
    isSettled: Boolean(participation.get('isSettled')),
    buySnapshot,
  };
}

function enrichParticipationDisplayFields(participations, costBasisPerShare) {
  if (!participations.length) return participations;
  const basis = Number(costBasisPerShare || 0);
  if (!(basis > 0)) return participations;

  const caps = participations.map((p) => Number(p.investmentCapital || 0));
  const tradeTotals = computeTradeLevelPoolBuyTotals(
    caps.reduce((s, c) => s + c, 0),
    basis,
  );
  const proRata = tradeTotals
    ? allocateProRataByInvestmentCapital(caps, tradeTotals)
    : [];

  return participations.map((p, i) => {
    const snap = p.buySnapshot;
    if (snap?.poolPieces > 0) {
      return {
        ...p,
        poolPieces: snap.poolPieces,
        activeInvestmentAtBid: round2(snap.poolCapitalAllocated || 0),
        investmentResidual: round2(snap.residualAmount ?? 0),
      };
    }
    const alloc = proRata[i];
    if (!alloc) return p;
    return {
      ...p,
      poolPieces: alloc.poolPieces,
      activeInvestmentAtBid: alloc.poolCapitalAllocated,
      investmentResidual: alloc.residualAmount,
    };
  });
}

module.exports = {
  loadParticipationsByPoolTradeIds,
  mapParticipationRow,
  enrichParticipationDisplayFields,
};
