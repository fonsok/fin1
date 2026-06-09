'use strict';

const { calculateOrderFees } = require('./helpers');
const { round2, round4 } = require('./accountingHelper/shared');
const {
  computeInvestorBuyLeg,
  computeInvestorSellLeg,
  deriveMirrorTradeBasis,
} = require('./accountingHelper/legs');

const APPLY_FOREIGN_COSTS_PHASE_A = true;

function buildSellLegFromQuantity(sellQty, sellPrice, feeConfig) {
  const qty = Number(sellQty || 0);
  const price = Number(sellPrice || 0);
  const sellAmt = price > 0 ? round2(qty * price) : 0;
  const sellFees = sellAmt > 0
    ? calculateOrderFees(sellAmt, APPLY_FOREIGN_COSTS_PHASE_A, feeConfig || {})
    : { orderFee: 0, exchangeFee: 0, foreignCosts: 0, totalFees: 0 };
  return { quantity: qty, price, amount: sellAmt, fees: sellFees };
}

/**
 * Pool-Stück am Trade-Einstand (SSOT = Summary/Participation-Anzeige).
 */
function investorPoolPiecesAtCostBasis(investmentCapital, costBasisPerShare) {
  const capital = Number(investmentCapital || 0);
  const basis = Number(costBasisPerShare || 0);
  if (!(capital > 0) || !(basis > 0)) {
    return { poolPieces: 0, activeAtBasis: 0, residualAmount: 0 };
  }
  const poolPieces = Math.floor(capital / basis);
  const activeAtBasis = round2(poolPieces * basis);
  const residualAmount = round2(Math.max(0, capital - activeAtBasis));
  return { poolPieces, activeAtBasis, residualAmount };
}

/**
 * Investor Teil-Sell-Delta: Stückzahl am Einstand (floor Kapital/Einstand), nicht Bid-Solver.
 */
function computeInvestorPartialSellDelta({
  investmentCapital,
  costBasisPerShare,
  tradeBuyPrice,
  tradeSellPrice,
  sellFraction,
  traderBuyQuantity,
  traderSoldBefore,
  traderSoldAfter,
  commissionRate,
  feeConfig,
}) {
  const capital = Number(investmentCapital || 0);
  const basis = Number(costBasisPerShare || 0);
  if (!(capital > 0) || !(sellFraction > 0)) return null;

  let poolPieces = 0;
  let activeAtBasis = 0;
  let buyFeesForSlice = 0;

  if (basis > 0) {
    const atCost = investorPoolPiecesAtCostBasis(capital, basis);
    poolPieces = atCost.poolPieces;
    activeAtBasis = atCost.activeAtBasis;
  } else {
    const bid = Number(tradeBuyPrice || 0);
    if (!(bid > 0)) return null;
    const buyLeg = computeInvestorBuyLeg(capital, bid, feeConfig || {});
    if (!buyLeg?.quantity) return null;
    poolPieces = buyLeg.quantity;
    activeAtBasis = round2(buyLeg.amount + (buyLeg.fees?.totalFees || 0));
    buyFeesForSlice = buyLeg.fees?.totalFees || 0;
  }

  if (!poolPieces) return null;

  const buyQty = Number(traderBuyQuantity || 0);
  const soldBefore = traderSoldBefore != null ? Number(traderSoldBefore) : null;
  const soldAfter = traderSoldAfter != null ? Number(traderSoldAfter) : null;
  // Kumulativ: bei Vollverkauf (soldAfter = buy) alle verbleibenden Pool-Stück, nicht pro Order floor.
  const useCumulativeRange = buyQty > 0 && soldBefore != null && soldAfter != null && soldAfter > soldBefore;

  const sellPrice = Number(tradeSellPrice || 0);
  if (!(sellPrice > 0)) return null;

  let sellQty = 0;
  if (useCumulativeRange) {
    const { poolSellDeltaForTraderSellRange } = require('./poolMirrorEconomics');
    sellQty = poolSellDeltaForTraderSellRange(poolPieces, soldBefore, soldAfter, buyQty);
  } else {
    sellQty = Number(
      computeInvestorSellLeg(poolPieces, sellPrice, sellFraction, feeConfig || {})?.quantity || 0,
    );
  }
  if (!sellQty) return null;

  const sellLeg = buildSellLegFromQuantity(sellQty, sellPrice, feeConfig);

  const sliceRatio = poolPieces > 0 ? sellQty / poolPieces : sellFraction;
  const buySlice = {
    amount: round2(activeAtBasis * sliceRatio),
    fees: { totalFees: round2(buyFeesForSlice * sliceRatio) },
    residualAmount: 0,
  };
  const derived = deriveMirrorTradeBasis(buySlice, sellLeg, commissionRate);
  if (!derived) return null;

  return {
    buyLeg: buySlice,
    sellLeg,
    grossProfit: derived.grossProfit,
    commission: derived.commission,
    netProfit: derived.netProfit,
    investorSellCashDelta: round2(sellLeg.amount),
    investorCostDelta: buySlice.amount,
    poolPieces,
    costBasisPerShare: basis > 0 ? round4(basis) : null,
  };
}

/**
 * Pool-Verkaufserlös über alle Trader-Teilverkäufe (je Order-Preis), nicht ein Durchschnittskurs.
 */
function aggregatePoolSellFromTraderSellOrders({
  investorPieceRows,
  traderSellOrders,
  traderBuyQuantity,
  feeConfig,
}) {
  const buyQty = Number(traderBuyQuantity || 0);
  if (!buyQty || !Array.isArray(traderSellOrders) || !traderSellOrders.length) {
    return null;
  }
  const { poolSellDeltaForTraderSellRange } = require('./poolMirrorEconomics');
  let cumulativeTraderSold = 0;
  let poolSoldQty = 0;
  let poolSellAmt = 0;
  let poolSellFees = 0;
  for (const order of traderSellOrders) {
    const deltaQty = Number(order.quantity || 0);
    if (!(deltaQty > 0)) continue;
    const traderSoldBefore = cumulativeTraderSold;
    cumulativeTraderSold += deltaQty;
    let price = Number(order.price || 0);
    if (!(price > 0) && order.totalAmount && deltaQty > 0) {
      price = Number(order.totalAmount) / deltaQty;
    }
    if (!(price > 0)) continue;
    for (let i = 0; i < investorPieceRows.length; i += 1) {
      const row = investorPieceRows[i];
      const rowDelta = poolSellDeltaForTraderSellRange(
        row.pieces,
        traderSoldBefore,
        cumulativeTraderSold,
        buyQty,
      );
      if (rowDelta > 0) {
        poolSoldQty += rowDelta;
        const sellLeg = buildSellLegFromQuantity(rowDelta, price, feeConfig);
        poolSellAmt += Number(sellLeg.amount || 0);
        poolSellFees += Number(sellLeg.fees?.totalFees || 0);
      }
    }
  }
  if (!poolSoldQty) return null;
  const gross = round2(poolSellAmt);
  const fees = round2(poolSellFees);
  return {
    poolSoldQuantityDerived: poolSoldQty,
    poolSellAmountDerived: gross,
    poolSellFeesTotal: fees,
    poolNetSellAmount: round2(gross - fees),
  };
}

function resolvePoolSellFromTraderReference(
  investorPieceRows,
  traderReference,
  { feeConfig, sellPrice, poolPieces },
) {
  const orders = traderReference?.sellOrders;
  const traderBuy = Number(traderReference?.buyQuantity || 0);
  if (orders?.length && traderBuy > 0) {
    const fromOrders = aggregatePoolSellFromTraderSellOrders({
      investorPieceRows,
      traderSellOrders: orders,
      traderBuyQuantity: traderBuy,
      feeConfig,
    });
    if (fromOrders) return fromOrders;
  }
  const traderSold = Number(traderReference?.soldQuantity || 0);
  const { resolvePoolSoldQtyCumulative } = require('./poolMirrorEconomics');
  if (!(sellPrice > 0) || !investorPieceRows.length) {
    const poolSoldQuantityDerived = traderBuy > 0
      ? resolvePoolSoldQtyCumulative(poolPieces, traderSold, traderBuy)
      : 0;
    return {
      poolSoldQuantityDerived,
      poolSellAmountDerived: 0,
      poolSellFeesTotal: 0,
      poolNetSellAmount: 0,
    };
  }
  let poolSoldQty = 0;
  let poolSellAmt = 0;
  let poolSellFees = 0;
  for (const row of investorPieceRows) {
    const rowSold = resolvePoolSoldQtyCumulative(row.pieces, traderSold, traderBuy);
    if (!(rowSold > 0)) continue;
    const sellLeg = buildSellLegFromQuantity(rowSold, sellPrice, feeConfig);
    poolSoldQty += rowSold;
    poolSellAmt += Number(sellLeg.amount || 0);
    poolSellFees += Number(sellLeg.fees?.totalFees || 0);
  }
  const gross = round2(poolSellAmt);
  const fees = round2(poolSellFees);
  return {
    poolSoldQuantityDerived: poolSoldQty,
    poolSellAmountDerived: gross,
    poolSellFeesTotal: fees,
    poolNetSellAmount: round2(gross - fees),
  };
}

module.exports = {
  investorPoolPiecesAtCostBasis,
  computeInvestorPartialSellDelta,
  aggregatePoolSellFromTraderSellOrders,
  resolvePoolSellFromTraderReference,
};
