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

/** Ask je Trader-Sell-Order (einzige Preis-Verknüpfung Trader→Pool). */
function normalizeSellPriceFromOrder(order) {
  const direct = Number(order?.price || order?.limitPrice || order?.averagePrice || 0);
  if (direct > 0) return round4(direct);
  const qty = Number(order?.quantity || 0);
  const total = Number(order?.totalAmount || 0);
  if (qty > 0 && total > 0) return round4(total / qty);
  return 0;
}

function resolveInvestorPieceRowsForPoolSell(participations, poolPieces) {
  if (Array.isArray(participations) && participations.length > 0) {
    const fromSnap = participations
      .map((p) => Number(p.buySnapshot?.poolPieces || p.poolPieces || 0))
      .filter((pieces) => pieces > 0)
      .map((pieces) => ({ pieces }));
    if (fromSnap.length > 0) return fromSnap;
  }
  const total = Number(poolPieces || 0);
  return total > 0 ? [{ pieces: total }] : [];
}

/**
 * SSOT: je Trader-Sell-Order Pool-Δ, Brutto, Gebühren (Summe investorPieceRows).
 * Summary-Aggregation und Partial-Sell-Events nutzen dieselbe Enumeration.
 */
function enumeratePoolSellEventsFromTraderOrders({
  investorPieceRows,
  traderSellOrders,
  traderBuyQuantity,
  feeConfig,
}) {
  const buyQty = Number(traderBuyQuantity || 0);
  if (!buyQty || !Array.isArray(traderSellOrders) || !traderSellOrders.length) {
    return [];
  }
  if (!Array.isArray(investorPieceRows) || investorPieceRows.length === 0) {
    return [];
  }

  const { poolSellDeltaForTraderSellRange, resolvePoolSoldQtyCumulative } = require('./poolMirrorEconomics');
  let cumulativeTraderSold = 0;
  const events = [];

  for (let sourceOrderIndex = 0; sourceOrderIndex < traderSellOrders.length; sourceOrderIndex += 1) {
    const order = traderSellOrders[sourceOrderIndex];
    const deltaQty = Number(order?.quantity || 0);
    if (!(deltaQty > 0)) continue;

    const traderSoldBefore = cumulativeTraderSold;
    cumulativeTraderSold += deltaQty;
    const sellPrice = normalizeSellPriceFromOrder(order);
    if (!(sellPrice > 0)) continue;

    let poolDeltaQty = 0;
    let poolGross = 0;
    let poolFees = 0;

    for (const row of investorPieceRows) {
      const rowDelta = poolSellDeltaForTraderSellRange(
        row.pieces,
        traderSoldBefore,
        cumulativeTraderSold,
        buyQty,
      );
      if (rowDelta > 0) {
        poolDeltaQty += rowDelta;
        const sellLeg = buildSellLegFromQuantity(rowDelta, sellPrice, feeConfig);
        poolGross += Number(sellLeg.amount || 0);
        poolFees += Number(sellLeg.fees?.totalFees || 0);
      }
    }

    if (!(poolDeltaQty > 0)) continue;

    const cumulativePoolSold = investorPieceRows.reduce(
      (sum, row) => sum + resolvePoolSoldQtyCumulative(row.pieces, cumulativeTraderSold, buyQty),
      0,
    );
    const gross = round2(poolGross);
    const fees = round2(poolFees);

    events.push({
      sourceOrderIndex,
      traderSellQuantity: round4(deltaQty),
      traderSoldBefore: round4(traderSoldBefore),
      traderSoldAfter: round4(cumulativeTraderSold),
      traderSellPrice: sellPrice,
      traderSellAmount: round2(Number(order?.totalAmount || 0)),
      sellFraction: round4(deltaQty / buyQty),
      traderSellVolumeProgress: round4(Math.min(1, cumulativeTraderSold / buyQty)),
      poolSellQuantity: round4(poolDeltaQty),
      poolSellQuantityCumulative: round4(cumulativePoolSold),
      poolSellAmount: gross,
      poolSellFeesTotal: fees,
      poolNetSellAmount: round2(gross - fees),
      isFinalExit: cumulativeTraderSold >= buyQty - 1e-4,
    });
  }

  return events;
}

/** Kumulierte Pool-Verkaufssummen über alle Trader-Sell-Orders. */
function aggregatePoolSellFromTraderSellOrders(params) {
  const events = enumeratePoolSellEventsFromTraderOrders(params);
  if (!events.length) return null;
  const last = events[events.length - 1];
  return {
    poolSoldQuantityDerived: last.poolSellQuantityCumulative,
    poolSellAmountDerived: round2(events.reduce((s, e) => s + e.poolSellAmount, 0)),
    poolSellFeesTotal: round2(events.reduce((s, e) => s + e.poolSellFeesTotal, 0)),
    poolNetSellAmount: round2(events.reduce((s, e) => s + e.poolNetSellAmount, 0)),
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
  normalizeSellPriceFromOrder,
  resolveInvestorPieceRowsForPoolSell,
  enumeratePoolSellEventsFromTraderOrders,
  aggregatePoolSellFromTraderSellOrders,
  resolvePoolSellFromTraderReference,
};
