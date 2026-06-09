'use strict';

const { tradeBuySideMetrics } = require('../../utils/accountingHelper/legPriceMetrics');
const { round2, round4 } = require('../../utils/accountingHelper/shared');
const {
  computeTradeLevelPoolBuyTotalsFromBid,
  allocateProRataByInvestmentCapital,
} = require('../../utils/poolMirrorEconomics/proRataAllocation');

function resolveTraderBuyMetrics(trade, buyOrder, feeConfig) {
  const buyPrice = Number(buyOrder?.price || trade.get('buyPrice') || 0);
  if (!(buyPrice > 0)) return null;

  const traderQuantity = Number(buyOrder?.quantity || trade.get('quantity') || 0);
  const traderGrossAmount = Number(buyOrder?.totalAmount || trade.get('buyAmount') || 0);
  const traderBuyMetrics = tradeBuySideMetrics({
    quantity: traderQuantity,
    grossAmount: traderGrossAmount,
    feeConfig,
  });
  if (!(traderBuyMetrics?.costBasisPerShare > 0)) return null;

  return { buyPrice, traderBuyMetrics };
}

function buildPoolBuySnapshotFromAllocation(trade, allocation, buyOrder, traderBuyMetrics) {
  if (!allocation || !(allocation.investmentAmount > 0)) return null;
  const buyPrice = Number(buyOrder?.price || trade.get('buyPrice') || 0);

  return {
    buyPrice: round4(buyPrice),
    costBasisPerShare: round4(traderBuyMetrics.costBasisPerShare),
    bidPricePerShare: traderBuyMetrics.bidPricePerShare ?? round4(buyPrice),
    buyFeesTotal: round2(traderBuyMetrics.buyFeesTotal || 0),
    totalBuyCost: round2(allocation.poolCapitalAllocated),
    poolPieces: allocation.poolPieces,
    poolCapitalAllocated: round2(allocation.poolCapitalAllocated),
    investmentAmount: round2(allocation.investmentAmount),
    residualAmount: round2(allocation.residualAmount),
    investmentCapitalShare: round4(allocation.investmentCapitalShare),
    snapshotAt: new Date().toISOString(),
  };
}

/**
 * Pro-Investor buySnapshot: Trade-Level SSOT, dann pro-rata nach Einlage.
 */
function buildPoolBuySnapshotsProRata(trade, investmentCapitals, buyOrder, { feeConfig = {} } = {}) {
  const caps = (investmentCapitals || []).map((c) => Number(c || 0)).filter((c) => c > 0);
  if (!caps.length) return [];

  const resolved = resolveTraderBuyMetrics(trade, buyOrder, feeConfig);
  if (!resolved) return [];

  const totalReserved = round2(caps.reduce((s, c) => s + c, 0));
  const tradeTotals = computeTradeLevelPoolBuyTotalsFromBid(
    totalReserved,
    resolved.buyPrice,
    feeConfig,
  );
  if (!tradeTotals?.impliedBuyQuantityFromPool) return [];

  const allocations = allocateProRataByInvestmentCapital(caps, tradeTotals);
  return allocations.map((allocation) =>
    buildPoolBuySnapshotFromAllocation(trade, allocation, buyOrder, resolved.traderBuyMetrics),
  ).filter(Boolean);
}

/**
 * Ein Investor: gleiche Pro-rata-Logik (100 % Anteil).
 */
function buildPoolBuySnapshot(trade, investmentCapital, buyOrder, options = {}) {
  const capital = Number(investmentCapital || 0);
  if (!(capital > 0)) return null;
  const snapshots = buildPoolBuySnapshotsProRata(trade, [capital], buyOrder, options);
  return snapshots[0] || null;
}

module.exports = {
  buildPoolBuySnapshot,
  buildPoolBuySnapshotsProRata,
  buildPoolBuySnapshotFromAllocation,
  computeTradeLevelPoolBuyTotalsFromBid,
  allocateProRataByInvestmentCapital,
};
