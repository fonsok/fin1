'use strict';

const { resolveSellOrdersFromTradeLike } = require('../../../triggers/tradeSellQuantityHelpers');
const { resolveTradeBuyPrice } = require('../../../utils/accountingHelper/shared');
const { resolveTradeCostBasisPerShare } = require('../../../utils/accountingHelper/legPriceMetrics');
const {
  resolvePoolSoldQtyCumulative,
  poolSellDeltaForTraderSellRange,
  computeInvestorPartialSellDelta,
  resolvePoolBuyQuantity,
} = require('../../../utils/poolMirrorEconomics');

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function round4(n) {
  return Math.round(Number(n) * 10000) / 10000;
}

function sortSellOrders(orders) {
  return [...orders].sort((a, b) => {
    const ta = a?.createdAt ? new Date(a.createdAt).getTime() : 0;
    const tb = b?.createdAt ? new Date(b.createdAt).getTime() : 0;
    return ta - tb;
  });
}

function resolveSellPriceFromOrder(order) {
  const direct = Number(order?.price || order?.limitPrice || order?.averagePrice || 0);
  if (direct > 0) return round4(direct);
  const qty = Number(order?.quantity || 0);
  const total = Number(order?.totalAmount || 0);
  if (qty > 0 && total > 0) return round4(total / qty);
  return 0;
}

/**
 * Teil-CB pro Investment und Event-Index (Reihenfolge wie partitionInvestorCollectionBills).
 */
function groupInvestorPartialSellBelegeByEvent(investorPartialSells, participations, eventCount) {
  const byInv = new Map();
  for (const link of investorPartialSells || []) {
    const invId = link.investmentId;
    if (!invId) continue;
    if (!byInv.has(invId)) byInv.set(invId, []);
    byInv.get(invId).push(link);
  }
  for (const arr of byInv.values()) {
    arr.sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')));
  }

  const eventBeleges = [];
  for (let i = 0; i < eventCount; i += 1) {
    const links = [];
    const orderedParticipations = participations.length
      ? participations
      : [...byInv.keys()].map((investmentId) => ({ investmentId }));
    for (const p of orderedParticipations) {
      const invLinks = byInv.get(p.investmentId) || [];
      if (invLinks[i]) links.push(invLinks[i]);
    }
    eventBeleges.push(links);
  }
  return eventBeleges;
}

/**
 * Per partial-sell event (delta), aligned with settlementDeltas sellFraction.
 */
function buildPartialSellEvents({
  traderTrade,
  poolTrade,
  poolMirrorSnap,
  participations = [],
  traderBelege,
  poolBelege,
  feeConfig = {},
  commissionRate = 0,
}) {
  if (!traderTrade || typeof traderTrade.get !== 'function') return [];

  const buyOrder = traderTrade.get('buyOrder') || {};
  const buyQuantity = Number(traderTrade.get('quantity') || buyOrder.quantity || 0);
  if (!(buyQuantity > 0)) return [];

  const sellOrders = sortSellOrders(resolveSellOrdersFromTradeLike(traderTrade));
  if (!sellOrders.length) return [];

  const tradeBuyPrice = resolveTradeBuyPrice(poolTrade || traderTrade);
  const costBasisPerShare = Number(poolMirrorSnap?.costBasisPerShare || 0)
    || resolveTradeCostBasisPerShare(traderTrade, feeConfig)
    || resolveTradeCostBasisPerShare(poolTrade, feeConfig)
    || null;
  const poolPieces = resolvePoolBuyQuantity({
    participations,
    poolMirrorTrade: poolMirrorSnap,
    traderTrade: {
      buyQuantity,
      costBasisPerShare,
    },
    costBasisPerShare,
  });
  const investorBelegeByEvent = groupInvestorPartialSellBelegeByEvent(
    poolBelege?.investorPartialSells,
    participations,
    sellOrders.length,
  );

  let cumulativeTraderQty = 0;
  const events = [];

  for (let i = 0; i < sellOrders.length; i += 1) {
    const order = sellOrders[i];
    const deltaQty = Number(order?.quantity || 0);
    if (!(deltaQty > 0)) continue;

    const deltaAmount = round2(Number(order?.totalAmount || 0));
    const sellFraction = round4(deltaQty / buyQuantity);
    const traderSoldBefore = cumulativeTraderQty;
    cumulativeTraderQty = round4(cumulativeTraderQty + deltaQty);
    const cumulativeTraderPct = round4(Math.min(1, cumulativeTraderQty / buyQuantity));

    const poolDeltaPieces = poolSellDeltaForTraderSellRange(
      poolPieces,
      traderSoldBefore,
      cumulativeTraderQty,
      buyQuantity,
    );
    const cumulativePoolSold = resolvePoolSoldQtyCumulative(poolPieces, cumulativeTraderQty, buyQuantity);

    const tradeSellPrice = resolveSellPriceFromOrder(order)
      || Number(poolMirrorSnap?.sellPrice || 0);

    const investorRealizations = participations.map((p) => {
      const capital = Number(p.investmentCapital || 0);
      const legDelta = computeInvestorPartialSellDelta({
        investmentCapital: capital,
        costBasisPerShare: p.buySnapshot?.costBasisPerShare || costBasisPerShare,
        tradeBuyPrice,
        tradeSellPrice,
        sellFraction,
        traderBuyQuantity: buyQuantity,
        traderSoldBefore,
        traderSoldAfter: cumulativeTraderQty,
        commissionRate,
        feeConfig,
      });
      if (!legDelta) {
        return {
          investmentId: p.investmentId,
          investmentNumber: p.investmentNumber || '',
          investorId: p.investorId,
          investorName: p.investorName || '',
          sellQuantity: 0,
          sellAmount: 0,
          grossProfit: 0,
          commission: 0,
          netProfit: 0,
          investorPayout: 0,
        };
      }
      return {
        investmentId: p.investmentId,
        investmentNumber: p.investmentNumber || '',
        investorId: p.investorId,
        investorName: p.investorName || '',
        sellQuantity: round4(legDelta.sellLeg.quantity),
        sellAmount: round2(legDelta.sellLeg.amount),
        grossProfit: round2(legDelta.grossProfit),
        commission: round2(legDelta.commission),
        netProfit: round2(legDelta.netProfit),
        investorPayout: round2(legDelta.investorSellCashDelta),
      };
    });

    const poolDeltaAmount = tradeSellPrice > 0 && poolDeltaPieces > 0
      ? round2(poolDeltaPieces * tradeSellPrice)
      : 0;

    events.push({
      eventIndex: events.length + 1,
      // Fachlich sold = buy; Toleranz wegen Float-Summen aus sellOrders.
      isFinalExit: cumulativeTraderQty >= buyQuantity - 0.0001,
      traderSellQuantity: round4(deltaQty),
      traderSellQuantityCumulative: round4(cumulativeTraderQty),
      traderSellAmount: deltaAmount,
      traderSellPrice: tradeSellPrice,
      traderSellVolumeProgress: cumulativeTraderPct,
      sellFraction,
      poolSellQuantity: poolDeltaPieces,
      poolSellQuantityCumulative: cumulativePoolSold,
      poolSellAmount: poolDeltaAmount,
      investorRealizations,
      traderSellBeleg: traderBelege?.sells?.[i] || null,
      poolMirrorSellBeleg: poolBelege?.traderExecution?.sells?.[i] || null,
      investorPartialSellBelege: investorBelegeByEvent[i] || [],
    });
  }

  return events;
}

function resolveTraderParseTradeForRow(row, tradeRow, tradeById) {
  const traderId =
    row.traderTrade?.tradeId
    || row.linkedTraderTrade?.tradeId
    || (row.legKind !== 'mirror_pool' ? tradeRow?.id : null);
  return traderId ? tradeById.get(traderId) || null : null;
}

function resolvePoolParseTradeForRow(row, tradeById) {
  const poolId = row.poolMirrorTrade?.tradeId || row.poolTradeId;
  return poolId ? tradeById.get(poolId) || null : null;
}

module.exports = {
  buildPartialSellEvents,
  groupInvestorPartialSellBelegeByEvent,
  resolveTraderParseTradeForRow,
  resolvePoolParseTradeForRow,
};
