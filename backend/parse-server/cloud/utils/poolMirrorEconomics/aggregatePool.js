'use strict';

const { round2 } = require('../accountingHelper/shared');
const {
  resolveBidPricePerShareFromTraderReference,
  resolvePoolMirrorBuyMetricsFromBid,
} = require('../accountingHelper/legPriceMetrics');
const { resolvePoolSellFromTraderReference } = require('../poolMirrorInvestorDelta');
const { ACTIVE_INVESTMENT_STATUSES } = require('./constants');
const {
  sumPoolPiecesFromParticipations,
  applyTradeLevelPoolCapitalTotals,
} = require('./resolvePoolMirrorState');
const {
  computeTradeLevelPoolBuyTotals,
  computeTradeLevelPoolBuyTotalsFromBid,
  allocateProRataByInvestmentCapital,
} = require('./proRataAllocation');

/**
 * Pool-Summary / Investor-Zeilen am Einstand des ausgeführten Legs (totalBuyCost / Stück).
 */
function aggregatePoolAtCostBasis(
  participations,
  costBasisPerShare,
  traderReference,
  options = {},
) {
  const feeConfig = options.feeConfig || {};
  const sellPrice = Number(options.sellPrice || 0);
  const basis = Number(costBasisPerShare || 0);

  if (!Array.isArray(participations) || participations.length === 0 || !(basis > 0)) {
    return {
      poolCapitalAllocated: 0,
      poolReservedCapitalTotal: 0,
      poolResidualTotal: 0,
      poolInvestorCount: 0,
      impliedBuyQuantityFromPool: null,
      poolSoldQuantityDerived: 0,
      poolSellAmountDerived: 0,
      poolSellFeesTotal: 0,
      poolNetSellAmount: 0,
      poolSellVolumeProgress: 0,
    };
  }

  let poolReservedCapital = 0;
  let poolPieces = 0;
  const activeInvestorIds = new Set();
  const investorPieceRows = [];

  const activeCaps = [];
  for (const p of participations) {
    const status = String(p.investmentStatus || '').toLowerCase();
    if (!ACTIVE_INVESTMENT_STATUSES.has(status)) continue;
    const capital = Number(p.investmentCapital || 0);
    if (!(capital > 0)) continue;
    poolReservedCapital += capital;
    activeCaps.push({ capital, investorId: p.investorId });
    if (p.investorId) activeInvestorIds.add(p.investorId);
  }

  poolReservedCapital = round2(poolReservedCapital);
  const tradeTotals = options.tradeTotalsFromBid
    || computeTradeLevelPoolBuyTotals(poolReservedCapital, basis);
  if (tradeTotals?.impliedBuyQuantityFromPool) {
    poolPieces = tradeTotals.impliedBuyQuantityFromPool;
    const allocations = allocateProRataByInvestmentCapital(
      activeCaps.map((r) => r.capital),
      tradeTotals,
    );
    for (let i = 0; i < allocations.length; i += 1) {
      investorPieceRows.push({
        pieces: allocations[i].poolPieces,
        capital: allocations[i].investmentAmount,
      });
    }
  }

  let poolSoldQuantityDerived = 0;
  let poolSellAmountDerived = 0;
  let poolSellFeesTotal = 0;
  let poolNetSellAmount = 0;
  let poolSellVolumeProgress = 0;
  if (traderReference && poolPieces > 0) {
    // Trade-Ebene: Sell-Sync auf Σ Pool-Stück (wie enumeratePoolSellEventsFromTraderOrders).
    const sellAgg = resolvePoolSellFromTraderReference([{ pieces: poolPieces }], traderReference, {
      feeConfig,
      sellPrice,
      poolPieces,
    });
    poolSoldQuantityDerived = sellAgg.poolSoldQuantityDerived;
    poolSellAmountDerived = sellAgg.poolSellAmountDerived;
    poolSellFeesTotal = Number(sellAgg.poolSellFeesTotal || 0);
    poolNetSellAmount = Number(sellAgg.poolNetSellAmount || 0);
    poolSellVolumeProgress = poolPieces > 0
      ? Math.round((poolSoldQuantityDerived / poolPieces) * 10000) / 10000
      : 0;
  }

  return applyTradeLevelPoolCapitalTotals({
    poolCapitalAllocated: 0,
    poolReservedCapitalTotal: poolReservedCapital,
    poolResidualTotal: 0,
    poolInvestorCount: activeInvestorIds.size,
    impliedBuyQuantityFromPool: poolPieces > 0 ? poolPieces : null,
    poolSoldQuantityDerived,
    poolSellAmountDerived: round2(poolSellAmountDerived),
    poolSellFeesTotal: round2(poolSellFeesTotal),
    poolNetSellAmount: round2(poolNetSellAmount),
    poolSellVolumeProgress,
    costBasisPerShare: tradeTotals?.costBasisPerShare || basis,
  }, tradeTotals?.costBasisPerShare || basis);
}

function aggregateFromParticipationBuySnapshots(rows, traderReference, { feeConfig, sellPrice }) {
  const poolPieces = sumPoolPiecesFromParticipations(rows);
  let poolReserved = 0;
  const investorIds = new Set();

  for (const p of rows) {
    const snap = p.buySnapshot || {};
    poolReserved += Number(snap.investmentAmount || p.investmentCapital || 0);
    if (p.investorId) investorIds.add(p.investorId);
  }

  let poolSoldQty = 0;
  let poolSellAmt = 0;
  let poolSellFees = 0;
  let poolNetSell = 0;
  let poolSellProgress = 0;
  if (traderReference && poolPieces > 0) {
    const pieceRows = rows.map((p) => ({ pieces: p.buySnapshot.poolPieces }));
    const sellAgg = resolvePoolSellFromTraderReference(pieceRows, traderReference, {
      feeConfig,
      sellPrice,
      poolPieces,
    });
    poolSoldQty = sellAgg.poolSoldQuantityDerived;
    poolSellAmt = sellAgg.poolSellAmountDerived;
    poolSellFees = Number(sellAgg.poolSellFeesTotal || 0);
    poolNetSell = Number(sellAgg.poolNetSellAmount || 0);
    poolSellProgress = poolPieces > 0
      ? Math.round((poolSoldQty / poolPieces) * 10000) / 10000
      : 0;
  }

  const bid = resolveBidPricePerShareFromTraderReference(traderReference);
  const poolBuyM = bid > 0 && poolPieces > 0
    ? resolvePoolMirrorBuyMetricsFromBid({ poolPieces, bidPricePerShare: bid, feeConfig })
    : null;
  let costBasis = Number(poolBuyM?.costBasisPerShare || 0);
  if (!(costBasis > 0) && traderReference) {
    costBasis = Number(traderReference.costBasisPerShare || 0);
  }
  return applyTradeLevelPoolCapitalTotals({
    poolCapitalAllocated: 0,
    poolReservedCapitalTotal: round2(poolReserved),
    poolResidualTotal: 0,
    poolInvestorCount: investorIds.size,
    impliedBuyQuantityFromPool: poolPieces > 0 ? poolPieces : null,
    poolSoldQuantityDerived: poolSoldQty,
    poolSellAmountDerived: round2(poolSellAmt),
    poolSellFeesTotal: round2(poolSellFees),
    poolNetSellAmount: round2(poolNetSell),
    poolSellVolumeProgress: poolSellProgress,
  }, costBasis);
}

function tryAggregateFromSnapshots(participations, traderReference, { feeConfig, sellPrice }) {
  if (!Array.isArray(participations) || participations.length === 0) return null;
  const active = participations.filter((p) =>
    ACTIVE_INVESTMENT_STATUSES.has(String(p.investmentStatus || '').toLowerCase()),
  );
  if (!active.length) return null;
  if (!active.every((p) => p.buySnapshot?.poolPieces > 0)) return null;
  return aggregateFromParticipationBuySnapshots(active, traderReference, { feeConfig, sellPrice });
}

/** Summary/Admin: completed investments still carry Collection-Bill buySnapshot SSOT. */
function tryAggregateFromParticipationSnapshots(participations, traderReference, { feeConfig, sellPrice }) {
  if (!Array.isArray(participations) || participations.length === 0) return null;
  const withSnap = participations.filter((p) => Number(p.buySnapshot?.poolPieces || 0) > 0);
  if (!withSnap.length) return null;
  return aggregateFromParticipationBuySnapshots(withSnap, traderReference, { feeConfig, sellPrice });
}

/**
 * SSOT = legs.js (Collection Bill). Summary-Pool nutzt optional Einstand des Trade-Legs.
 * @param {object} [options] feeConfig, sellPrice, costBasisPerShare (optional; sonst nur Bid)
 */
function aggregatePoolInvestmentEconomics(
  participations,
  buyPrice,
  traderReference = null,
  options = {},
) {
  const feeConfig = options.feeConfig || {};
  const sellPrice = Number(options.sellPrice || 0);
  const bid = Number(
    buyPrice
    || resolveBidPricePerShareFromTraderReference(traderReference),
  );

  const snapshotResult = tryAggregateFromSnapshots(participations, traderReference, { feeConfig, sellPrice })
    || tryAggregateFromParticipationSnapshots(participations, traderReference, { feeConfig, sellPrice });
  if (snapshotResult) return snapshotResult;

  let costBasis = Number(options.costBasisPerShare || 0);
  let tradeTotalsFromBid = null;
  if (bid > 0 && !(costBasis > 0)) {
    let poolReserved = 0;
    for (const p of participations) {
      const status = String(p.investmentStatus || '').toLowerCase();
      if (!ACTIVE_INVESTMENT_STATUSES.has(status)) continue;
      poolReserved += Number(p.investmentCapital || 0);
    }
    tradeTotalsFromBid = computeTradeLevelPoolBuyTotalsFromBid(round2(poolReserved), bid, feeConfig);
    if (tradeTotalsFromBid?.costBasisPerShare > 0) {
      costBasis = tradeTotalsFromBid.costBasisPerShare;
    }
  }

  if (costBasis > 0) {
    return aggregatePoolAtCostBasis(participations, costBasis, traderReference, {
      feeConfig,
      sellPrice,
      tradeTotalsFromBid,
    });
  }

  return {
    poolCapitalAllocated: 0,
    poolReservedCapitalTotal: 0,
    poolResidualTotal: 0,
    poolInvestorCount: 0,
    impliedBuyQuantityFromPool: null,
    poolSoldQuantityDerived: 0,
    poolSellAmountDerived: 0,
    poolSellVolumeProgress: 0,
  };
}

module.exports = {
  aggregatePoolAtCostBasis,
  aggregatePoolInvestmentEconomics,
};
