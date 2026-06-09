'use strict';

const { round2, round4 } = require('../accountingHelper/shared');
const { ACTIVE_INVESTMENT_STATUSES } = require('./constants');
const { poolCapitalFromPiecesAndBasis } = require('./proRataAllocation');
const { resolvePoolSoldQtyCumulative, TRADER_FULL_SELL_EPSILON } = require('./traderSellMath');

const PROGRESS_EPSILON = 1e-4;

/**
 * SSOT: Pool-Stück aus Participation-Zeilen.
 * 1) buySnapshot.poolPieces (Collection Bill, jeder Status)
 * 2) poolPieces-Feld (enriched rows)
 * 3) floor(investmentCapital / costBasis) nur für active/executing
 */
function sumPoolPiecesFromParticipations(participations, { costBasisPerShare } = {}) {
  if (!Array.isArray(participations) || participations.length === 0) return 0;

  let fromSnapshot = 0;
  let snapshotRows = 0;
  for (const p of participations) {
    const pieces = Number(p.buySnapshot?.poolPieces || p.poolPieces || 0);
    if (pieces > 0) {
      fromSnapshot += pieces;
      snapshotRows += 1;
    }
  }
  if (snapshotRows > 0) return fromSnapshot;

  const basis = Number(costBasisPerShare || 0);
  if (!(basis > 0)) return 0;

  let totalCap = 0;
  for (const p of participations) {
    const status = String(p.investmentStatus || '').toLowerCase();
    if (!ACTIVE_INVESTMENT_STATUSES.has(status)) continue;
    totalCap += Number(p.investmentCapital || 0);
  }
  if (!(totalCap > 0)) return 0;
  const { computeTradeLevelPoolBuyTotals } = require('./proRataAllocation');
  return Number(computeTradeLevelPoolBuyTotals(totalCap, basis)?.impliedBuyQuantityFromPool || 0);
}

function isMirrorBuyPlaceholder(mirrorBuy, traderBuy) {
  return mirrorBuy > 0 && traderBuy > 0 && mirrorBuy === traderBuy;
}

/** Pool-Einlage = Σ Stück × Einstand (Anzeige) — SSOT: proRataAllocation.poolCapitalFromPiecesAndBasis */
const resolvePoolMirrorTradeCapitalAllocated = poolCapitalFromPiecesAndBasis;

function applyTradeLevelPoolCapitalTotals(economics, costBasisPerShare) {
  if (!economics?.impliedBuyQuantityFromPool || !(Number(costBasisPerShare) > 0)) {
    return economics;
  }
  const poolCapitalAllocated = resolvePoolMirrorTradeCapitalAllocated(
    economics.impliedBuyQuantityFromPool,
    costBasisPerShare,
  );
  const poolReservedCapitalTotal = round2(Number(economics.poolReservedCapitalTotal || 0));
  return {
    ...economics,
    poolCapitalAllocated,
    poolResidualTotal: round2(Math.max(0, poolReservedCapitalTotal - poolCapitalAllocated)),
  };
}

/**
 * Einheitliche Pool-Kaufstück-Auflösung (Report, sellSync, Partial-Sell-Events).
 */
function resolvePoolBuyQuantity({
  participations = [],
  poolMirrorTrade = null,
  traderTrade = null,
  costBasisPerShare,
} = {}) {
  const fromPoolField = Number(poolMirrorTrade?.impliedBuyQuantityFromPool || 0);
  if (fromPoolField > 0) return fromPoolField;

  const basis = Number(
    costBasisPerShare
    || traderTrade?.costBasisPerShare
    || poolMirrorTrade?.costBasisPerShare
    || 0,
  );
  const fromParticipations = sumPoolPiecesFromParticipations(participations, { costBasisPerShare: basis });
  if (fromParticipations > 0) return fromParticipations;

  const mirrorBuy = Number(poolMirrorTrade?.buyQuantity || 0);
  const traderBuy = Number(traderTrade?.buyQuantity || 0);
  if (isMirrorBuyPlaceholder(mirrorBuy, traderBuy)) return 0;
  return mirrorBuy;
}

function derivePoolSellState(poolPieces, traderTrade) {
  const traderBuy = Number(traderTrade?.buyQuantity || 0);
  const traderSold = Number(traderTrade?.soldQuantity || 0);
  if (!(traderBuy > 0) || !(poolPieces > 0) || !(traderSold > 0)) {
    return { soldQuantity: 0, sellVolumeProgress: 0 };
  }
  const sold = resolvePoolSoldQtyCumulative(poolPieces, traderSold, traderBuy);
  return {
    soldQuantity: round4(sold),
    sellVolumeProgress: round4(Math.min(1, sold / poolPieces)),
  };
}

function applyPoolMirrorEconomicsToSnapshot(poolMirrorSnap, traderTrade, participations = [], options = {}) {
  if (!poolMirrorSnap || !traderTrade) return poolMirrorSnap;

  const poolBuy = resolvePoolBuyQuantity({
    participations,
    poolMirrorTrade: poolMirrorSnap,
    traderTrade,
    costBasisPerShare: options.costBasisPerShare,
  });
  if (!(poolBuy > 0)) return poolMirrorSnap;

  const { soldQuantity, sellVolumeProgress } = derivePoolSellState(poolBuy, traderTrade);
  return {
    ...poolMirrorSnap,
    buyQuantity: round4(poolBuy),
    impliedBuyQuantityFromPool: poolBuy,
    soldQuantity,
    sellVolumeProgress,
  };
}

/**
 * Snapshot-first mit gezieltem Patch nur bei veralteten DB-/Trade-Feldern.
 */
function reconcilePoolMirrorSnapshot(poolMirrorSnap, traderTrade, participations = [], options = {}) {
  if (!poolMirrorSnap || !traderTrade) return poolMirrorSnap;

  const poolBuy = resolvePoolBuyQuantity({
    participations,
    poolMirrorTrade: poolMirrorSnap,
    traderTrade,
    costBasisPerShare: options.costBasisPerShare,
  });
  const traderSold = Number(traderTrade.soldQuantity || 0);
  if (!(poolBuy > 0) || !(traderSold > 0)) return poolMirrorSnap;

  const { soldQuantity, sellVolumeProgress } = derivePoolSellState(poolBuy, traderTrade);
  const poolSold = Number(poolMirrorSnap.soldQuantity || 0);
  const poolProgress = Number(poolMirrorSnap.sellVolumeProgress || 0);
  const traderBuy = Number(traderTrade.buyQuantity || 0);

  const wrongPoolBuy = Number(poolMirrorSnap.buyQuantity || 0) !== poolBuy;
  const progressLags = sellVolumeProgress > poolProgress + PROGRESS_EPSILON
    || poolProgress + PROGRESS_EPSILON < Number(traderTrade.sellVolumeProgress || 0);
  const traderFullySold = traderSold >= traderBuy - TRADER_FULL_SELL_EPSILON;
  const poolFullySold = poolSold >= poolBuy - TRADER_FULL_SELL_EPSILON;
  const staleWhileTraderComplete = traderFullySold && !poolFullySold;

  if (!wrongPoolBuy && !progressLags && !staleWhileTraderComplete) {
    return poolMirrorSnap;
  }

  return {
    ...poolMirrorSnap,
    buyQuantity: round4(poolBuy),
    impliedBuyQuantityFromPool: poolBuy,
    soldQuantity,
    sellVolumeProgress,
  };
}

module.exports = {
  sumPoolPiecesFromParticipations,
  resolvePoolBuyQuantity,
  resolvePoolMirrorTradeCapitalAllocated,
  applyTradeLevelPoolCapitalTotals,
  derivePoolSellState,
  applyPoolMirrorEconomicsToSnapshot,
  reconcilePoolMirrorSnapshot,
  isMirrorBuyPlaceholder,
};
