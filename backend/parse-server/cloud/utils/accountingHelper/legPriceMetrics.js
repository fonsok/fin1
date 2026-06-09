'use strict';

const { calculateOrderFees } = require('../helpers');
const { totalSellQuantity } = require('../../triggers/tradeSellQuantityHelpers');
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

/**
 * Offene Position: P/L = −Kaufvolumen (Einstand). Mit Verkauf: Erlös − (verkaufte Stück × Einstand).
 */
function resolveLegProfitFromMetrics(snapWithLegMetrics, sellAmount, soldQuantity) {
  const totalBuyCost = Number(
    snapWithLegMetrics.totalBuyCost ?? snapWithLegMetrics.buyAmount ?? 0,
  );
  const costBasis = Number(snapWithLegMetrics.costBasisPerShare || 0);
  const sold = Number(soldQuantity || 0);
  const displayBasis = round2(costBasis);

  if (sold > 0 && displayBasis > 0) {
    const grossSell = Number(snapWithLegMetrics.netSellAmount ?? sellAmount ?? 0);
    return round2(grossSell - round2(sold * displayBasis));
  }
  if (sold <= 0 && totalBuyCost > 0) {
    return round2(-totalBuyCost);
  }
  return round2(Number(sellAmount || 0) - Number(snapWithLegMetrics.buyAmount ?? 0));
}

/** Rendite in % auf Einstand-Basis (Kaufvolumen inkl. Gebühren). */
function resolveLegReturnPercentage(totalBuyCost, profit) {
  const buyAmount = Number(totalBuyCost || 0);
  const p = Number(profit || 0);
  if (!(buyAmount > 0)) return 0;
  return Math.round((p / buyAmount) * 10000) / 100;
}

function extractTradeOrderAmountsFromParseTrade(trade) {
  if (!trade || typeof trade.get !== 'function') {
    return { buyQuantity: 0, buyGross: 0, sellGross: 0, soldQuantity: 0 };
  }
  const buyOrder = trade.get('buyOrder') || {};
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder') || {};
  const buyQuantity = Number(trade.get('quantity') || buyOrder.quantity || 0);
  const buyGross = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);
  let sellGross = Number(sellOrder.totalAmount || trade.get('sellAmount') || 0);
  if (sellOrders.length > 0) {
    sellGross = sellOrders.reduce((s, o) => s + Number(o?.totalAmount || 0), 0);
  }
  const soldQuantity = Number(trade.get('soldQuantity') || 0) || totalSellQuantity(trade);
  return { buyQuantity, buyGross, sellGross, soldQuantity };
}

/** Admin-Listen: Trader-Leg Einstand, P/L und Rendite ohne Report-Overlay. */
function tradeListEconomicsFromParseTrade(trade, feeConfig = {}) {
  const { buyQuantity, buyGross, sellGross, soldQuantity } = extractTradeOrderAmountsFromParseTrade(trade);
  const snapWithLegMetrics = attachLegPriceMetricsToSnapshot(
    {
      buyQuantity: round4(buyQuantity),
      soldQuantity: round4(soldQuantity),
      buyAmount: round2(buyGross),
      sellAmount: round2(sellGross),
    },
    feeConfig,
  );
  const profit = resolveLegProfitFromMetrics(snapWithLegMetrics, sellGross, soldQuantity);
  const buyAmount = Number(snapWithLegMetrics.totalBuyCost ?? buyGross);
  return {
    buyAmount,
    sellAmount: round2(sellGross),
    profit,
    returnPercentage: resolveLegReturnPercentage(buyAmount, profit),
    totalBuyCost: buyAmount,
  };
}

/** Einzige Trader→Pool-Verknüpfung: nomineller Bid pro Stück. */
function resolveBidPricePerShareFromTraderReference(traderReference) {
  if (!traderReference) return 0;
  return Number(traderReference.bidPricePerShare || traderReference.buyPrice || 0);
}

/**
 * Pool-Mirror-Kauforder: Stück × Bid + Gebühren auf Pool-Brutto (unabhängig vom Trader-Leg).
 */
function resolvePoolMirrorBuyMetricsFromBid({ poolPieces, bidPricePerShare, feeConfig = {} }) {
  const pieces = Number(poolPieces || 0);
  const bid = Number(bidPricePerShare || 0);
  if (!(pieces > 0) || !(bid > 0)) return null;
  return tradeBuySideMetrics({
    quantity: pieces,
    grossAmount: round2(pieces * bid),
    feeConfig,
  });
}

/** Ask/Netto pro Stück aus Pool-Verkaufs-Summen (Display). */
function resolvePoolMirrorSellPricePerShare({ poolSoldQuantity, poolSellGross, poolNetSellAmount }) {
  const sold = Number(poolSoldQuantity || 0);
  if (!(sold > 0)) {
    return { askPricePerShare: null, netSellPricePerShare: null };
  }
  const gross = Number(poolSellGross || 0);
  const net = Number(poolNetSellAmount || 0);
  return {
    askPricePerShare: gross > 0 ? round4(gross / sold) : null,
    netSellPricePerShare: net > 0 ? round4(net / sold) : null,
  };
}

/** Einstand-Hinweis für floor(Reserved/Einstand) — nur Bid, keine Trader-Gebühren/-Stückzahl. */
function resolvePoolCostBasisHintFromBid(poolReservedCapital, bidPricePerShare, feeConfig = {}) {
  const reserved = round2(Number(poolReservedCapital || 0));
  const bid = Number(bidPricePerShare || 0);
  if (!(reserved > 0) || !(bid > 0)) return 0;
  const estPieces = Math.max(1, Math.floor(reserved / bid));
  const m = resolvePoolMirrorBuyMetricsFromBid({
    poolPieces: estPieces,
    bidPricePerShare: bid,
    feeConfig,
  });
  return Number(m?.costBasisPerShare || 0);
}

/** Trade-Leg Einstand pro Stück (Gebühren im Stückpreis) — SSOT für Pool-Stückzahl. */
function resolveTradeCostBasisPerShare(trade, feeConfig = {}) {
  if (!trade || typeof trade.get !== 'function') return null;
  const buyOrder = trade.get('buyOrder') || {};
  const qty = Number(trade.get('quantity') || buyOrder.quantity || 0);
  const gross = Number(trade.get('buyAmount') || buyOrder.totalAmount || 0);
  if (!(qty > 0) || !(gross > 0)) return null;
  const m = tradeBuySideMetrics({ quantity: qty, grossAmount: gross, feeConfig });
  return m?.costBasisPerShare ?? null;
}

module.exports = {
  totalBuyCostFromBuyLeg,
  costBasisPerShareFromBuyLeg,
  resolveTradeCostBasisPerShare,
  resolveBidPricePerShareFromTraderReference,
  resolvePoolMirrorBuyMetricsFromBid,
  resolvePoolMirrorSellPricePerShare,
  resolvePoolCostBasisHintFromBid,
  resolveLegProfitFromMetrics,
  resolveLegReturnPercentage,
  extractTradeOrderAmountsFromParseTrade,
  tradeListEconomicsFromParseTrade,
  netSellAmountFromSellLeg,
  netSellPricePerShareFromSellLeg,
  tradeBuySideMetrics,
  tradeSellSideMetrics,
  enrichBuyLegWithPriceMetrics,
  enrichSellLegWithPriceMetrics,
  attachLegPriceMetricsToSnapshot,
};
