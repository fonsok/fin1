'use strict';

/**
 * Float-Toleranz für „Trader hat alle Stück verkauft“ (sold = buy).
 * Fachlich gilt sold = buy; im Code sold >= buy - ε wegen Summen-Rundung aus sellOrders.
 */
const TRADER_FULL_SELL_EPSILON = 1e-6;

function floorPoolPiecesFromCapital(investmentCapital, buyPrice) {
  const capital = Number(investmentCapital || 0);
  const price = Number(buyPrice || 0);
  if (!(price > 0) || !(capital > 0)) return 0;
  return Math.floor(capital / price);
}

/**
 * Kumulativ: wie viele Pool-Stück nach traderSoldQty / traderBuyQty verkauft sein sollen.
 * Bei Vollverkauf (sold = buy): alle poolPieces — kein 597/598-Rundungsrest.
 */
function resolvePoolSoldQtyCumulative(poolPieces, traderSoldQty, traderBuyQty) {
  const pieces = Number(poolPieces || 0);
  const sold = Number(traderSoldQty || 0);
  const buyQty = Number(traderBuyQty || 0);
  if (!(pieces > 0) || !(buyQty > 0) || !(sold > 0)) return 0;
  if (sold >= buyQty - TRADER_FULL_SELL_EPSILON) return pieces;
  return Math.floor(pieces * Math.min(1, sold / buyQty));
}

/**
 * Trader-Leg-Teilverkauf → Pool-Stück (abrunden). sellFraction = kumulativer Anteil am Trader-Leg.
 * sellFraction = 1 (100 %) → alle poolPieces (analog sold = buy).
 */
function poolSellQuantityForTraderSellFraction(poolPieces, sellFraction) {
  const pieces = Number(poolPieces || 0);
  const frac = Number(sellFraction || 0);
  if (!(pieces > 0) || !(frac > 0)) return 0;
  if (frac >= 1 - TRADER_FULL_SELL_EPSILON) return pieces;
  return Math.floor(pieces * Math.min(1, frac));
}

/**
 * Delta Pool-Stück für eine Trader-Verkaufsbewegung (kumulativ, verhindert Reststück).
 * Erreicht traderSoldAfter den Vollverkauf (sold = buy), wird das letzte Stück mitverkauft.
 */
function poolSellDeltaForTraderSellRange(poolPieces, traderSoldBefore, traderSoldAfter, traderBuyQty) {
  const after = resolvePoolSoldQtyCumulative(poolPieces, traderSoldAfter, traderBuyQty);
  const before = resolvePoolSoldQtyCumulative(poolPieces, traderSoldBefore, traderBuyQty);
  return Math.max(0, after - before);
}

module.exports = {
  TRADER_FULL_SELL_EPSILON,
  floorPoolPiecesFromCapital,
  resolvePoolSoldQtyCumulative,
  poolSellQuantityForTraderSellFraction,
  poolSellDeltaForTraderSellRange,
};
