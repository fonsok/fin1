'use strict';

const { totalSellQuantity } = require('../../triggers/tradeSellQuantityHelpers');
const { round2, round4 } = require('../accountingHelper/shared');
const {
  attachLegPriceMetricsToSnapshot,
  resolveLegProfitFromMetrics,
  resolveBidPricePerShareFromTraderReference,
  resolvePoolMirrorBuyMetricsFromBid,
  resolvePoolMirrorSellPricePerShare,
} = require('../accountingHelper/legPriceMetrics');
const { aggregatePoolInvestmentEconomics } = require('./aggregatePool');
const { reconcilePoolMirrorSnapshot } = require('./resolvePoolMirrorState');
const {
  isPersistedLegEconomicsCurrent,
  legEconomicsFromPersisted,
} = require('./legEconomicsPersistShared');

function weightedAvgSellPrice(sellOrders) {
  let qtySum = 0;
  let amtSum = 0;
  for (const o of sellOrders) {
    const q = Number(o?.quantity || 0);
    const px = Number(o?.price || 0);
    if (q > 0 && px > 0) {
      qtySum += q;
      amtSum += q * px;
    }
  }
  if (qtySum > 0) return round4(amtSum / qtySum);
  return 0;
}

function extractInstrumentFields(trade) {
  const buyOrder = trade.get('buyOrder') || {};
  const wkn = String(trade.get('wkn') || buyOrder.wkn || '').trim();
  const isin = String(trade.get('isin') || buyOrder.isin || '').trim();
  const symbol = String(trade.get('symbol') || buyOrder.symbol || '').trim();
  const wknOrIsin = wkn || isin || symbol || null;
  const strike = Number(trade.get('strikePrice') || buyOrder.strikePrice || 0);
  return {
    wkn: wkn || null,
    isin: isin || null,
    wknOrIsin,
    symbol,
    underlyingAsset: trade.get('underlyingAsset') || buyOrder.underlyingAsset || null,
    issuer: trade.get('issuer') || buyOrder.issuer || null,
    optionDirection: trade.get('optionDirection') || buyOrder.optionDirection || null,
    strikePrice: strike > 0 ? round4(strike) : null,
  };
}

/** Pool-Mirror: nur Bid vom Trader; Kauf/Gebühren/Einstand aus Pool-Order. */
function applyPoolMirrorEconomicsOverrides(snap, poolEconomics, feeConfig = {}) {
  if (!snap || !poolEconomics?.impliedBuyQuantityFromPool) return snap;
  const pieces = poolEconomics.impliedBuyQuantityFromPool;
  const sold = Number(poolEconomics.poolSoldQuantityDerived || 0);
  const buyAmt = poolEconomics.poolCapitalAllocated;
  const bid = Number(snap.bidPricePerShare || snap.buyPrice || 0);
  const poolBuyM = resolvePoolMirrorBuyMetricsFromBid({
    poolPieces: pieces,
    bidPricePerShare: bid,
    feeConfig,
  });
  const costBasis = Number(poolBuyM?.costBasisPerShare || snap.costBasisPerShare || 0);
  const grossSell = round2(Number(poolEconomics.poolSellAmountDerived || 0));
  const poolSellFeesTotal = round2(Number(poolEconomics.poolSellFeesTotal || 0));
  const poolNetSellAmount = round2(
    poolEconomics.poolNetSellAmount != null
      ? Number(poolEconomics.poolNetSellAmount)
      : Math.max(0, grossSell - poolSellFeesTotal),
  );
  const sellPx = resolvePoolMirrorSellPricePerShare({
    poolSoldQuantity: sold,
    poolSellGross: grossSell,
    poolNetSellAmount,
  });
  const profit = resolveLegProfitFromMetrics(
    {
      totalBuyCost: buyAmt,
      costBasisPerShare: costBasis,
      buyAmount: buyAmt,
      netSellAmount: poolNetSellAmount,
    },
    grossSell,
    sold,
  );

  return {
    ...snap,
    buyQuantity: pieces,
    soldQuantity: sold,
    sellVolumeProgress: poolEconomics.poolSellVolumeProgress,
    bidPricePerShare: bid > 0 ? round4(bid) : snap.bidPricePerShare,
    buyFeesTotal: poolBuyM?.buyFeesTotal ?? 0,
    costBasisPerShare: costBasis,
    totalBuyCost: poolBuyM?.totalBuyCost ?? buyAmt,
    sellAmount: grossSell,
    netSellAmount: poolNetSellAmount,
    sellFeesTotal: poolSellFeesTotal,
    netSellPricePerShare: sellPx.netSellPricePerShare ?? snap.netSellPricePerShare,
    askPricePerShare: sellPx.askPricePerShare ?? snap.askPricePerShare,
    profit,
    poolCapitalAllocated: poolEconomics.poolCapitalAllocated,
    poolReservedCapitalTotal: poolEconomics.poolReservedCapitalTotal,
    poolResidualTotal: poolEconomics.poolResidualTotal,
    poolInvestorCount: poolEconomics.poolInvestorCount,
    impliedBuyQuantityFromPool: pieces,
  };
}

function resolveImmutableBuyInputsForSnapshot(trade, traderReference, applyPoolMirror) {
  const buyOrder = trade.get('buyOrder') || {};
  let buyQuantity = Number(trade.get('quantity') || buyOrder.quantity || 0);
  let buyAmount = Number(buyOrder.totalAmount || trade.get('buyAmount') || 0);
  let buyPrice = Number(
    buyOrder.price || trade.get('buyPrice') || trade.get('entryPrice') || 0,
  );

  if (applyPoolMirror && traderReference) {
    buyPrice = Number(
      traderReference.bidPricePerShare || traderReference.buyPrice || buyPrice,
    );
  }

  return { buyQuantity, buyAmount, buyPrice };
}

/**
 * Domain-SSOT: Trader- und Pool-Mirror-Leg Economics (Read-Path Admin/Reports).
 * Verknüpfung Trader↔Pool: nur Bid (Kauf) bzw. Ask je Sell-Order (Verkauf).
 */
function tradeEconomicsSnapshot(trade, participations = null, options = {}) {
  if (!trade) return null;

  if (options.preferPersisted !== false) {
    const persisted = trade.get?.('legEconomicsSnapshot');
    if (isPersistedLegEconomicsCurrent(persisted, trade)) {
      const applyPoolMirror = Boolean(options.applyPoolMirror && participations?.length);
      if (!applyPoolMirror || Number(persisted.impliedBuyQuantityFromPool || 0) > 0) {
        return legEconomicsFromPersisted(persisted, trade);
      }
    }
  }

  const instrument = extractInstrumentFields(trade);
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder') || {};
  const resolvedSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
  const traderReference = options.traderReference || null;
  const applyPoolMirror = Boolean(options.applyPoolMirror && participations?.length);
  const {
    buyQuantity,
    buyAmount,
    buyPrice: resolvedBuyPrice,
  } = resolveImmutableBuyInputsForSnapshot(trade, traderReference, applyPoolMirror);
  let sellAmount = Number(sellOrder.totalAmount || trade.get('sellAmount') || 0);
  if (sellOrders.length > 0) {
    sellAmount = sellOrders.reduce((s, o) => s + Number(o?.totalAmount || 0), 0);
  }
  const soldQuantity = Number(trade.get('soldQuantity') || 0) || totalSellQuantity(trade);
  const buyPrice = resolvedBuyPrice;
  let sellPrice = Number(
    sellOrder.price || trade.get('exitPrice') || trade.get('sellPrice') || 0,
  );
  if (resolvedSells.length > 0) {
    const avg = weightedAvgSellPrice(resolvedSells);
    if (avg > 0) sellPrice = avg;
  }
  const feeConfig = options.feeConfig || {};
  let poolEconomics = null;
  const snapWithLegMetrics = attachLegPriceMetricsToSnapshot(
    {
      tradeId: trade.id,
      buyQuantity: round4(buyQuantity),
      soldQuantity: round4(soldQuantity),
      buyAmount: round2(buyAmount),
      sellAmount: round2(sellAmount),
      buyPrice: round4(buyPrice),
      sellPrice: round4(sellPrice),
    },
    feeConfig,
  );

  const profit = resolveLegProfitFromMetrics(snapWithLegMetrics, sellAmount, soldQuantity);

  if (participations?.length) {
    if (applyPoolMirror && traderReference) {
      const bidOnly = resolveBidPricePerShareFromTraderReference(traderReference);
      if (bidOnly > 0) {
        snapWithLegMetrics.bidPricePerShare = round4(bidOnly);
      }
    }
    poolEconomics = aggregatePoolInvestmentEconomics(
      participations,
      buyPrice,
      traderReference,
      { feeConfig, sellPrice },
    );
  }

  const base = {
    tradeId: trade.id,
    tradeNumber: trade.get('tradeNumber') || 0,
    tradeNumberYear: trade.get('tradeNumberYear') || null,
    symbol: instrument.symbol || 'N/A',
    description: trade.get('description') || '',
    status: trade.get('status') || 'unknown',
    traderId: trade.get('traderId') || '',
    ...instrument,
    buyQuantity: snapWithLegMetrics.buyQuantity,
    soldQuantity: snapWithLegMetrics.soldQuantity,
    sellVolumeProgress: buyQuantity > 0 ? round4(Math.min(1, soldQuantity / buyQuantity)) : 0,
    buyPrice: snapWithLegMetrics.bidPricePerShare ?? round4(buyPrice),
    sellPrice: snapWithLegMetrics.askPricePerShare ?? round4(sellPrice),
    buyAmount: snapWithLegMetrics.totalBuyCost ?? round2(buyAmount),
    sellAmount: snapWithLegMetrics.netSellAmount ?? round2(sellAmount),
    profit: round2(profit),
    bidPricePerShare: snapWithLegMetrics.bidPricePerShare,
    buyFeesTotal: snapWithLegMetrics.buyFeesTotal,
    totalBuyCost: snapWithLegMetrics.totalBuyCost,
    costBasisPerShare: snapWithLegMetrics.costBasisPerShare,
    askPricePerShare: snapWithLegMetrics.askPricePerShare,
    sellFeesTotal: snapWithLegMetrics.sellFeesTotal,
    netSellAmount: snapWithLegMetrics.netSellAmount,
    netSellPricePerShare: snapWithLegMetrics.netSellPricePerShare,
    poolCapitalAllocated: poolEconomics?.poolCapitalAllocated ?? 0,
    poolReservedCapitalTotal: poolEconomics?.poolReservedCapitalTotal ?? 0,
    poolResidualTotal: poolEconomics?.poolResidualTotal ?? 0,
    poolInvestorCount: poolEconomics?.poolInvestorCount ?? 0,
    impliedBuyQuantityFromPool: poolEconomics?.impliedBuyQuantityFromPool ?? null,
    sellOrders: resolvedSells.map((o) => ({
      quantity: Number(o?.quantity || 0),
      totalAmount: Number(o?.totalAmount || 0),
      price: Number(o?.price || 0),
    })),
    createdAt: trade.get('createdAt'),
    completedAt: trade.get('completedAt') || null,
  };

  let result = base;
  if (applyPoolMirror && poolEconomics?.impliedBuyQuantityFromPool) {
    result = applyPoolMirrorEconomicsOverrides(base, poolEconomics, feeConfig);
  }
  if (applyPoolMirror && traderReference && participations?.length) {
    const poolBasis = Number(result.costBasisPerShare || 0);
    result = reconcilePoolMirrorSnapshot(result, traderReference, participations, {
      costBasisPerShare: poolBasis,
    });
  }
  return result;
}

module.exports = {
  tradeEconomicsSnapshot,
  applyPoolMirrorEconomicsOverrides,
  resolveImmutableBuyInputsForSnapshot,
  extractInstrumentFields,
  weightedAvgSellPrice,
};
