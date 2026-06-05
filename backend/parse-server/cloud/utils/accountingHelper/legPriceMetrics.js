'use strict';

const { calculateOrderFees } = require('../helpers');
const { round2, round4 } = require('./shared');

/** Gesamtkaufkosten inkl. Gebühren (Collection Bill / Einstand). */
function totalBuyCostFromBuyLeg(buyLeg) {
  if (!buyLeg) return 0;
  return round2(Number(buyLeg.amount || 0) + Number(buyLeg.fees?.totalFees || 0));
}

/** Einstandspreis / Bezugspreis pro Stück = totalBuyCost / quantity. */
function costBasisPerShareFromBuyLeg(buyLeg) {
  const qty = Number(buyLeg?.quantity || 0);
  if (!(qty > 0)) return null;
  return round4(totalBuyCostFromBuyLeg(buyLeg) / qty);
}

/** Netto-Verkaufserlös nach Gebühren. */
function netSellAmountFromSellLeg(sellLeg) {
  if (!sellLeg) return 0;
  return round2(Number(sellLeg.amount || 0) - Number(sellLeg.fees?.totalFees || 0));
}

/** Netto-Verkaufspreis pro Stück. */
function netSellPricePerShareFromSellLeg(sellLeg) {
  const qty = Number(sellLeg?.quantity || 0);
  if (!(qty > 0)) return null;
  return round4(netSellAmountFromSellLeg(sellLeg) / qty);
}

function feesForOrderAmount(amount, feeConfig) {
  const fees = calculateOrderFees(Number(amount || 0), true, feeConfig || {});
  return {
    orderFee: round2(fees.orderFee || 0),
    exchangeFee: round2(fees.exchangeFee || 0),
    foreignCosts: round2(fees.foreignCosts || 0),
    totalFees: round2(fees.totalFees || 0),
  };
}

/**
 * Trade-/Summary-Kaufseite: Bid ≠ Einstand (Gebühren im Stückpreis).
 */
function tradeBuySideMetrics({ quantity, grossAmount, feeConfig }) {
  const qty = Number(quantity || 0);
  const gross = Number(grossAmount || 0);
  if (!(qty > 0) || !(gross > 0)) return null;
  const fees = feesForOrderAmount(gross, feeConfig);
  const totalBuyCost = round2(gross + fees.totalFees);
  return {
    buyFeesTotal: fees.totalFees,
    buyFees: fees,
    totalBuyCost,
    costBasisPerShare: round4(totalBuyCost / qty),
    bidPricePerShare: round4(gross / qty),
  };
}

/**
 * Trade-/Summary-Verkaufseite: Ask ≠ netto pro Stück.
 */
function tradeSellSideMetrics({ quantity, grossAmount, feeConfig }) {
  const qty = Number(quantity || 0);
  const gross = Number(grossAmount || 0);
  if (!(qty > 0) || !(gross > 0)) return null;
  const fees = feesForOrderAmount(gross, feeConfig);
  const netSellAmount = round2(gross - fees.totalFees);
  return {
    sellFeesTotal: fees.totalFees,
    sellFees: fees,
    netSellAmount,
    netSellPricePerShare: round4(netSellAmount / qty),
    askPricePerShare: round4(gross / qty),
  };
}

function enrichBuyLegWithPriceMetrics(buyLeg) {
  if (!buyLeg || typeof buyLeg !== 'object') return buyLeg;
  const totalBuyCost = totalBuyCostFromBuyLeg(buyLeg);
  const costBasisPerShare = costBasisPerShareFromBuyLeg(buyLeg);
  return Object.assign({}, buyLeg, {
    totalBuyCost: round2(buyLeg.totalBuyCost ?? totalBuyCost),
    costBasisPerShare: buyLeg.costBasisPerShare ?? costBasisPerShare,
  });
}

function enrichSellLegWithPriceMetrics(sellLeg) {
  if (!sellLeg || typeof sellLeg !== 'object') return sellLeg;
  const netSellAmount = netSellAmountFromSellLeg(sellLeg);
  const netSellPricePerShare = netSellPricePerShareFromSellLeg(sellLeg);
  return Object.assign({}, sellLeg, {
    netSellAmount: sellLeg.netSellAmount ?? netSellAmount,
    netSellPricePerShare: sellLeg.netSellPricePerShare ?? netSellPricePerShare,
  });
}

function attachLegPriceMetricsToSnapshot(snap, feeConfig) {
  if (!snap) return snap;
  const buyM = tradeBuySideMetrics({
    quantity: snap.buyQuantity,
    grossAmount: snap.buyAmount,
    feeConfig,
  });
  const sellM = tradeSellSideMetrics({
    quantity: snap.soldQuantity,
    grossAmount: snap.sellAmount,
    feeConfig,
  });
  return Object.assign({}, snap, {
    bidPricePerShare: buyM?.bidPricePerShare ?? snap.buyPrice,
    buyFeesTotal: buyM?.buyFeesTotal ?? 0,
    totalBuyCost: buyM?.totalBuyCost ?? round2(snap.buyAmount),
    costBasisPerShare: buyM?.costBasisPerShare ?? null,
    askPricePerShare: sellM?.askPricePerShare ?? snap.sellPrice,
    sellFeesTotal: sellM?.sellFeesTotal ?? 0,
    netSellAmount: sellM?.netSellAmount ?? round2(snap.sellAmount),
    netSellPricePerShare: sellM?.netSellPricePerShare ?? null,
  });
}

module.exports = {
  totalBuyCostFromBuyLeg,
  costBasisPerShareFromBuyLeg,
  netSellAmountFromSellLeg,
  netSellPricePerShareFromSellLeg,
  tradeBuySideMetrics,
  tradeSellSideMetrics,
  enrichBuyLegWithPriceMetrics,
  enrichSellLegWithPriceMetrics,
  attachLegPriceMetricsToSnapshot,
};
