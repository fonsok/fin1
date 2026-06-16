'use strict';

const { round2 } = require('../../../utils/accountingHelper/shared');
const {
  computeTradeLevelPoolBuyTotals,
  allocateProRataByInvestmentCapital,
} = require('../../../utils/poolMirrorEconomics/proRataAllocation');
const { DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE } = require('../../../services/poolMirrorActivation/poolMirrorLimits');
const {
  readSummaryReportInlineParticipationsMax,
  readParticipationsPageSize,
} = require('../../../services/poolMirrorActivation/poolMirrorScaleLimits');
const { readAggregateGroupKey } = require('./summaryReportAggregateKey');

function participationQueryLimitForTradeIds(tradeIds) {
  const n = Math.max(1, tradeIds.length);
  return Math.min(10000, n * DEFAULT_MAX_INVESTORS_PER_MIRROR_TRADE);
}

async function loadParticipationCountsByPoolTradeIds(poolTradeIds) {
  const ids = [...new Set(poolTradeIds.filter(Boolean))];
  const map = new Map();
  if (!ids.length) return map;

  const pipeline = [
    { $match: { tradeId: { $in: ids } } },
    { $group: { _id: '$tradeId', count: { $sum: 1 } } },
  ];
  const rows = await new Parse.Query('PoolTradeParticipation').aggregate(pipeline, { useMasterKey: true });
  for (const row of rows) {
    const tradeId = readAggregateGroupKey(row);
    if (!tradeId) continue;
    map.set(tradeId, Number(row.count) || 0);
  }
  for (const id of ids) {
    if (!map.has(id)) map.set(id, 0);
  }
  return map;
}

async function loadParticipationAggregatesByPoolTradeIds(poolTradeIds) {
  const ids = [...new Set(poolTradeIds.filter(Boolean))];
  const map = new Map();
  if (!ids.length) return map;

  const pipeline = [
    { $match: { tradeId: { $in: ids } } },
    {
      $group: {
        _id: '$tradeId',
        count: { $sum: 1 },
        totalCommission: { $sum: '$commissionAmount' },
        totalProfitShare: { $sum: '$profitShare' },
      },
    },
  ];
  const rows = await new Parse.Query('PoolTradeParticipation').aggregate(pipeline, { useMasterKey: true });
  for (const row of rows) {
    const tradeId = readAggregateGroupKey(row);
    if (!tradeId) continue;
    map.set(tradeId, {
      count: Number(row.count) || 0,
      totalCommission: round2(Number(row.totalCommission) || 0),
      totalProfitShare: round2(Number(row.totalProfitShare) || 0),
    });
  }
  for (const id of ids) {
    if (!map.has(id)) {
      map.set(id, { count: 0, totalCommission: 0, totalProfitShare: 0 });
    }
  }
  return map;
}

async function enrichParticipationParseRows(partList) {
  const investmentIds = new Set();
  for (const p of partList) {
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

  return partList.map((p) => mapParticipationRow(p, investmentById, userById));
}

async function loadParticipationsByPoolTradeIds(poolTradeIds) {
  const ids = [...new Set(poolTradeIds.filter(Boolean))];
  if (!ids.length) return new Map();

  const pq = new Parse.Query('PoolTradeParticipation');
  pq.containedIn('tradeId', ids);
  pq.ascending('createdAt');
  pq.limit(participationQueryLimitForTradeIds(ids));
  const parts = await pq.find({ useMasterKey: true });

  const byTrade = new Map();
  for (const p of parts) {
    const tid = p.get('tradeId');
    if (!tid) continue;
    if (!byTrade.has(tid)) byTrade.set(tid, []);
    byTrade.get(tid).push(p);
  }

  const enrichedByTrade = new Map();
  for (const [tid, partList] of byTrade) {
    // eslint-disable-next-line no-await-in-loop
    enrichedByTrade.set(tid, await enrichParticipationParseRows(partList));
  }
  return enrichedByTrade;
}

async function loadParticipationsBundleForSummaryReport(poolTradeIds) {
  const ids = [...new Set(poolTradeIds.filter(Boolean))];
  const inlineMax = readSummaryReportInlineParticipationsMax();
  const [counts, aggregates] = await Promise.all([
    loadParticipationCountsByPoolTradeIds(ids),
    loadParticipationAggregatesByPoolTradeIds(ids),
  ]);

  const fullLoadIds = ids.filter((id) => {
    const count = counts.get(id) || 0;
    return count > 0 && count <= inlineMax;
  });

  const participationsByPool = await loadParticipationsByPoolTradeIds(fullLoadIds);
  for (const id of ids) {
    if (!participationsByPool.has(id)) participationsByPool.set(id, []);
  }

  return {
    participationsByPool,
    participationCountsByPool: counts,
    participationAggregatesByPool: aggregates,
    inlineMax,
  };
}

async function loadParticipationsPageForPoolTrade(poolTradeId, { page = 0, pageSize } = {}) {
  const tradeId = String(poolTradeId || '').trim();
  if (!tradeId) {
    return { items: [], total: 0, page: 0, pageSize: readParticipationsPageSize(pageSize) };
  }

  const effectivePageSize = readParticipationsPageSize(pageSize);
  const safePage = Math.max(0, parseInt(page, 10) || 0);

  const baseQuery = new Parse.Query('PoolTradeParticipation').equalTo('tradeId', tradeId);
  const [total, parts] = await Promise.all([
    baseQuery.count({ useMasterKey: true }),
    new Parse.Query('PoolTradeParticipation')
      .equalTo('tradeId', tradeId)
      .ascending('createdAt')
      .skip(safePage * effectivePageSize)
      .limit(effectivePageSize)
      .find({ useMasterKey: true }),
  ]);

  const items = await enrichParticipationParseRows(parts);
  return { items, total, page: safePage, pageSize: effectivePageSize };
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

function participationForApiResponse(participation) {
  if (!participation || typeof participation !== 'object') return participation;
  const { buySnapshot, ...rest } = participation;
  void buySnapshot;
  return rest;
}

function enrichParticipationDisplayFields(participations, costBasisPerShare) {
  if (!participations.length) return participations;
  const basis = Number(costBasisPerShare || 0);

  const caps = participations.map((p) => Number(p.investmentCapital || 0));
  const tradeTotals = basis > 0
    ? computeTradeLevelPoolBuyTotals(caps.reduce((s, c) => s + c, 0), basis)
    : null;
  const proRata = tradeTotals
    ? allocateProRataByInvestmentCapital(caps, tradeTotals)
    : [];

  return participations.map((p, i) => {
    const snap = p.buySnapshot;
    let enriched = p;
    if (snap?.poolPieces > 0) {
      enriched = {
        ...p,
        poolPieces: snap.poolPieces,
        activeInvestmentAtBid: round2(snap.poolCapitalAllocated || 0),
        investmentResidual: round2(snap.residualAmount ?? 0),
      };
    } else {
      const alloc = proRata[i];
      if (alloc) {
        enriched = {
          ...p,
          poolPieces: alloc.poolPieces,
          activeInvestmentAtBid: alloc.poolCapitalAllocated,
          investmentResidual: alloc.residualAmount,
        };
      }
    }
    return participationForApiResponse(enriched);
  });
}

module.exports = {
  loadParticipationsByPoolTradeIds,
  loadParticipationsBundleForSummaryReport,
  loadParticipationCountsByPoolTradeIds,
  loadParticipationAggregatesByPoolTradeIds,
  loadParticipationsPageForPoolTrade,
  mapParticipationRow,
  enrichParticipationDisplayFields,
};
