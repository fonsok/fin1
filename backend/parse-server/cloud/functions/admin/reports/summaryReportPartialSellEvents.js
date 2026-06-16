'use strict';

const { resolveSellOrdersFromTradeLike } = require('../../../triggers/tradeSellQuantityHelpers');
const { resolveTradeBuyPrice } = require('../../../utils/accountingHelper/shared');
const { resolveTradeCostBasisPerShare } = require('../../../utils/accountingHelper/legPriceMetrics');
const { resolvePoolBuyQuantity } = require('../../../utils/poolMirrorEconomics');
const {
  computeInvestorPartialSellDelta,
  enumeratePoolSellEventsFromTraderOrders,
  resolveInvestorPieceRowsForPoolSell,
} = require('../../../utils/poolMirrorInvestorDelta');

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
 * Pool-Stück/Brutto/Gebühren: SSOT enumeratePoolSellEventsFromTraderOrders.
 */
function buildPartialSellEvents({
  traderTrade,
  poolTrade,
  poolMirrorSnap,
  participations = [],
  participationsTruncated = false,
  participationsTotal = 0,
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
  const investorPieceRows = participationsTruncated
    ? []
    : resolveInvestorPieceRowsForPoolSell(participations, poolPieces);
  const poolSellEvents = enumeratePoolSellEventsFromTraderOrders({
    investorPieceRows,
    traderSellOrders: sellOrders,
    traderBuyQuantity: buyQuantity,
    feeConfig,
  });
  const investorBelegesByEvent = groupInvestorPartialSellBelegeByEvent(
    poolBelege?.investorPartialSells,
    participations,
    sellOrders.length,
  );

  const events = [];
  for (const poolEvent of poolSellEvents) {
    const i = poolEvent.sourceOrderIndex;
    const investorRealizations = participationsTruncated
      ? []
      : participations.map((p) => {
      const capital = Number(p.investmentCapital || 0);
      const legDelta = computeInvestorPartialSellDelta({
        investmentCapital: capital,
        costBasisPerShare: p.buySnapshot?.costBasisPerShare || costBasisPerShare,
        tradeBuyPrice,
        tradeSellPrice: poolEvent.traderSellPrice,
        sellFraction: poolEvent.sellFraction,
        traderBuyQuantity: buyQuantity,
        traderSoldBefore: poolEvent.traderSoldBefore,
        traderSoldAfter: poolEvent.traderSoldAfter,
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

    events.push({
      eventIndex: events.length + 1,
      isFinalExit: poolEvent.isFinalExit,
      traderSellQuantity: poolEvent.traderSellQuantity,
      traderSellQuantityCumulative: poolEvent.traderSoldAfter,
      traderSellAmount: poolEvent.traderSellAmount,
      traderSellPrice: poolEvent.traderSellPrice,
      traderSellVolumeProgress: poolEvent.traderSellVolumeProgress,
      sellFraction: poolEvent.sellFraction,
      poolSellQuantity: poolEvent.poolSellQuantity,
      poolSellQuantityCumulative: poolEvent.poolSellQuantityCumulative,
      poolSellAmount: poolEvent.poolSellAmount,
      poolSellFeesTotal: poolEvent.poolSellFeesTotal,
      poolNetSellAmount: poolEvent.poolNetSellAmount,
      investorRealizations,
      investorRealizationsTruncated: participationsTruncated,
      investorRealizationsTotal: participationsTruncated ? participationsTotal : investorRealizations.length,
      traderSellBeleg: traderBelege?.sells?.[i] || null,
      poolMirrorSellBeleg: poolBelege?.traderExecution?.sells?.[i] || null,
      investorPartialSellBelege: investorBelegesByEvent[i] || [],
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
