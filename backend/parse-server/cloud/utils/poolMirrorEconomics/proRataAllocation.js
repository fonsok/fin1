'use strict';

const { round2, round4 } = require('../accountingHelper/shared');

function poolCapitalFromPiecesAndBasis(poolPieces, costBasisPerShare) {
  const pieces = Number(poolPieces || 0);
  const basis = Number(costBasisPerShare || 0);
  if (!(pieces > 0) || !(basis > 0)) return 0;
  return round2(pieces * round2(basis));
}

/**
 * Trade-Ebene: Stück = floor(Σ Einlagen / Einstand), Einlage = Stück × Einstand (Anzeige), Rest = Reserved − Einlage.
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
  computeTradeLevelPoolBuyTotals,
  allocateProRataByInvestmentCapital,
};
