'use strict';

const { tradeBuySideMetrics } = require('../accountingHelper/legPriceMetrics');
const { round2, round4 } = require('../accountingHelper/shared');

function poolCapitalFromPiecesAndBasis(poolPieces, costBasisPerShare) {
  const pieces = Number(poolPieces || 0);
  const basis = Number(costBasisPerShare || 0);
  if (!(pieces > 0) || !(basis > 0)) return 0;
  return round2(pieces * round2(basis));
}

function poolCostBasisForPieces(pieces, bidPricePerShare, feeConfig = {}) {
  const qty = Number(pieces || 0);
  const bid = Number(bidPricePerShare || 0);
  if (!(qty > 0) || !(bid > 0)) return 0;
  const metrics = tradeBuySideMetrics({
    quantity: qty,
    grossAmount: round2(qty * bid),
    feeConfig,
  });
  return Number(metrics?.costBasisPerShare || 0);
}

function poolCapitalAtPieces(pieces, bidPricePerShare, feeConfig = {}) {
  return poolCapitalFromPiecesAndBasis(
    pieces,
    poolCostBasisForPieces(pieces, bidPricePerShare, feeConfig),
  );
}

/**
 * Pool-Leg SSOT: max. n mit n × Einstand(n) ≤ Reserved.
 * Einstand(n) = Bid + Gebühren auf (n × Bid) / n — nur Bid vom Trader, keine Trader-Stückzahl.
 */
function computeTradeLevelPoolBuyTotalsFromBid(poolReservedCapitalTotal, bidPricePerShare, feeConfig = {}) {
  const reserved = round2(Number(poolReservedCapitalTotal || 0));
  const bid = Number(bidPricePerShare || 0);
  if (!(reserved > 0) || !(bid > 0)) return null;

  let n = Math.max(1, Math.floor(reserved / bid));
  while (n > 0 && poolCapitalAtPieces(n, bid, feeConfig) > reserved + 0.005) {
    n -= 1;
  }
  if (n <= 0) return null;
  while (poolCapitalAtPieces(n + 1, bid, feeConfig) <= reserved + 0.005) {
    n += 1;
  }

  const costBasisPerShare = poolCostBasisForPieces(n, bid, feeConfig);
  const poolCapitalAllocated = poolCapitalFromPiecesAndBasis(n, costBasisPerShare);
  const poolResidualTotal = round2(Math.max(0, reserved - poolCapitalAllocated));

  return {
    poolReservedCapitalTotal: reserved,
    impliedBuyQuantityFromPool: n,
    poolCapitalAllocated,
    poolResidualTotal,
    costBasisPerShare,
    bidPricePerShare: bid,
  };
}

/**
 * Trade-Ebene bei bekanntem Einstand: Stück = floor(Σ Einlagen / Einstand), Einlage = Stück × Einstand, Rest = Reserved − Einlage.
 */
function computeTradeLevelPoolBuyTotals(poolReservedCapitalTotal, costBasisPerShare) {
  const reserved = round2(Number(poolReservedCapitalTotal || 0));
  const basis = Number(costBasisPerShare || 0);
  if (!(reserved > 0) || !(basis > 0)) return null;

  const impliedBuyQuantityFromPool = Math.floor(reserved / basis);
  const poolCapitalAllocated = poolCapitalFromPiecesAndBasis(impliedBuyQuantityFromPool, basis);
  const poolResidualTotal = round2(Math.max(0, reserved - poolCapitalAllocated));

  return {
    poolReservedCapitalTotal: reserved,
    impliedBuyQuantityFromPool,
    poolCapitalAllocated,
    poolResidualTotal,
    costBasisPerShare: basis,
  };
}

/**
 * Pro-Investor-Anteil proportional zur Einlage (GoB).
 * Stück intern mit Nachkommastellen; letzter Investor erhält Rundungsrest.
 */
function allocateProRataByInvestmentCapital(investmentCapitals, tradeTotals) {
  if (!tradeTotals || !Array.isArray(investmentCapitals) || investmentCapitals.length === 0) {
    return [];
  }

  const caps = investmentCapitals.map((c) => round2(Number(c || 0)));
  const totalCap = round2(caps.reduce((s, c) => s + c, 0));
  if (!(totalCap > 0)) return [];

  const totalPieces = Number(tradeTotals.impliedBuyQuantityFromPool || 0);
  const totalPoolCapital = round2(Number(tradeTotals.poolCapitalAllocated || 0));
  const totalResidual = round2(Number(tradeTotals.poolResidualTotal || 0));

  let sumCapital = 0;
  let sumResidual = 0;
  let sumPieces = 0;
  const lastIdx = caps.length - 1;

  return caps.map((capital, i) => {
    const isLast = i === lastIdx;
    const share = capital / totalCap;

    let poolCapitalAllocated;
    let residualAmount;
    let poolPieces;

    if (isLast) {
      poolCapitalAllocated = round2(totalPoolCapital - sumCapital);
      residualAmount = round2(totalResidual - sumResidual);
      poolPieces = round4(totalPieces - sumPieces);
    } else {
      poolCapitalAllocated = round2(totalPoolCapital * share);
      residualAmount = round2(totalResidual * share);
      poolPieces = round4(totalPieces * share);
      sumCapital += poolCapitalAllocated;
      sumResidual += residualAmount;
      sumPieces += poolPieces;
    }

    return {
      investmentAmount: capital,
      investmentCapitalShare: share,
      poolPieces,
      poolCapitalAllocated,
      residualAmount,
    };
  });
}

module.exports = {
  poolCapitalFromPiecesAndBasis,
  poolCostBasisForPieces,
  poolCapitalAtPieces,
  computeTradeLevelPoolBuyTotalsFromBid,
  computeTradeLevelPoolBuyTotals,
  allocateProRataByInvestmentCapital,
};
