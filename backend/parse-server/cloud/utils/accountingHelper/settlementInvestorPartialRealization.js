'use strict';

const { createCommissionRateResolver, loadConfig } = require('../configHelper/index.js');
const { round2 } = require('./shared');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { createPartialSellInternalBeleg } = require('./documents');
const { resolveDocumentReference } = require('./documentReferenceResolver');
const {
  getTotalSellQuantity,
  getSellOrdersAddedSince,
  resolveSellOrderKey,
} = require('./settlementTradeMath');
const { audit } = require('../structuredLogger');
const {
  bookPartialSellPoolRelease,
  bookPartialSellProfitRecognition,
  hasEscrowLeg,
} = require('./investmentEscrow');
const { prefetchInvestmentsById } = require('./settlementQueries');
const { findInvestment } = require('./settlementInvestmentFallback');
const { resolveTradeBuyPrice, resolveTradeSellPrice } = require('./shared');
const { resolveTradeCostBasisPerShare } = require('./legPriceMetrics');
const {
  resolvePoolContextForTraderSell,
  computeInvestorPartialSellDelta,
} = require('../poolMirrorEconomics');
const { normalizeSellPriceFromOrder } = require('../poolMirrorInvestorDelta');
const { getOrderArrayFromTradeLike } = require('./settlementTradeMath');

function sortSellOrdersChronologically(orders) {
  return [...orders].sort((a, b) => {
    const ta = a?.createdAt ? new Date(a.createdAt).getTime() : 0;
    const tb = b?.createdAt ? new Date(b.createdAt).getTime() : 0;
    return ta - tb;
  });
}

function tradeSnapshotForPartialReplay(traderTrade, { sellOrders, soldQuantity }) {
  const Trade = Parse.Object.extend('Trade');
  const row = new Trade();
  row.id = traderTrade.id;
  const json = typeof traderTrade.toJSON === 'function' ? traderTrade.toJSON() : {};
  Object.keys(json).forEach((key) => {
    if (key === 'objectId' || key === 'createdAt' || key === 'updatedAt' || key === 'ACL') return;
    row.set(key, json[key]);
  });
  row.set('sellOrders', sellOrders);
  row.set('soldQuantity', soldQuantity);
  row.unset('sellOrder');
  return row;
}

/**
 * Idempotent replay of all investor partial-sell deltas (EBP + escrow) for a trader leg.
 * Repairs completion saves where trade_sell index errors skipped the investor hook.
 */
async function ensureInvestorPartialSellDeltasForTraderLeg(traderTrade) {
  if (!traderTrade?.id) return [];

  const allSells = sortSellOrdersChronologically(getOrderArrayFromTradeLike(traderTrade));
  if (!allSells.length) return [];

  let previous = tradeSnapshotForPartialReplay(traderTrade, { sellOrders: [], soldQuantity: 0 });
  const results = [];
  const prefix = [];

  for (const order of allSells) {
    prefix.push(order);
    const soldQuantity = round2(
      prefix.reduce((sum, o) => sum + Number(o?.quantity || 0), 0),
    );
    const current = tradeSnapshotForPartialReplay(traderTrade, {
      sellOrders: [...prefix],
      soldQuantity,
    });
    const delta = await bookInvestorPartialRealizationDeltaIfAny({
      trade: current,
      previousTrade: previous,
    });
    if (delta) results.push(delta);
    previous = current;
  }

  return results;
}

async function bookPartialSellEscrowForInvestor({
  investorId,
  investment,
  investmentNumber,
  poolTrade,
  tradeNumber,
  sellOrderId,
  poolCapitalReleased,
  sellLeg,
  grossProfitDelta,
  netProfitDelta,
  commissionDelta,
  investorSellCashDelta,
  businessCaseId,
}) {
  const internalBeleg = await createPartialSellInternalBeleg({
    investorId,
    investmentId: investment.id,
    investmentNumber,
    trade: poolTrade,
    sellOrderId,
    poolCapitalReleased,
    sellLeg,
    grossProfit: grossProfitDelta,
    netProfit: netProfitDelta,
    commission: commissionDelta,
    businessCaseId,
  });
  if (!internalBeleg) return null;

  const internalBelegRef = resolveDocumentReference(internalBeleg, { context: 'partial_sell_internal_beleg' });
  const tradeId = poolTrade.id;

  await bookPartialSellPoolRelease({
    investorId,
    investmentId: investment.id,
    investmentNumber,
    tradeId,
    tradeNumber,
    sellOrderId,
    poolCapitalReleased,
    businessCaseId,
    internalBelegRef,
  });

  const releaseBooked = await hasEscrowLeg(investment.id, 'partialSellRelease', {
    tradeId,
    sellOrderId,
  });
  if (!releaseBooked) {
    audit.error('escrow.partialSell.releaseMissing', {
      investmentId: investment.id,
      tradeId,
      tradeNumber: tradeNumber || null,
      sellOrderId,
      poolCapitalReleased,
      message: 'Partial-sell Eigenbeleg exists but CLT-LIAB-PTR (1592) release leg missing — retrying once',
    });
    await bookPartialSellPoolRelease({
      investorId,
      investmentId: investment.id,
      investmentNumber,
      tradeId,
      tradeNumber,
      sellOrderId,
      poolCapitalReleased,
      businessCaseId,
      internalBelegRef,
    });
  }

  if (grossProfitDelta > 0) {
    await bookPartialSellProfitRecognition({
      investorId,
      investmentId: investment.id,
      investmentNumber,
      tradeId,
      tradeNumber,
      sellOrderId,
      grossProfit: grossProfitDelta,
      businessCaseId,
      internalBelegRef,
    });
  }

  return {
    investorId,
    investmentId: investment.id,
    sellOrderId,
    poolCapitalReleased,
    deltaSellAmount: investorSellCashDelta,
    deltaGrossProfit: grossProfitDelta,
    deltaCommission: commissionDelta,
    deltaNetProfit: netProfitDelta,
  };
}

async function bookInvestorPartialRealizationForSellOrderDelta({
  poolCtx,
  previousTrade,
  trade,
  sellOrder,
}) {
  const { poolTrade, traderTrade, participations } = poolCtx;
  const sellOrderId = resolveSellOrderKey(sellOrder);
  if (!sellOrderId) return [];

  const previousSellQty = getTotalSellQuantity(previousTrade);
  const currentSellQty = getTotalSellQuantity(trade);
  const deltaSellQty = round2(currentSellQty - previousSellQty);
  if (!Number.isFinite(deltaSellQty) || deltaSellQty <= 0) return [];

  const buyOrder = traderTrade.get('buyOrder') || {};
  const buyQuantity = Number(traderTrade.get('quantity') || buyOrder.quantity || 0);
  if (!Number.isFinite(buyQuantity) || buyQuantity <= 0) return [];

  const sellFraction = deltaSellQty / buyQuantity;
  const tradeNumber = poolTrade.get('tradeNumber') || traderTrade.get('tradeNumber');
  const businessCaseId = await ensureBusinessCaseIdForTrade(traderTrade);
  const traderId = traderTrade.get('traderId');
  const commissionRateResolver = await createCommissionRateResolver();
  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const tradeBuyPrice = resolveTradeBuyPrice(poolTrade);
  const tradeSellPrice = sellOrder
    ? normalizeSellPriceFromOrder(sellOrder)
    : resolveTradeSellPrice(traderTrade);
  if (!(tradeSellPrice > 0)) return [];
  const costBasisPerShare = resolveTradeCostBasisPerShare(traderTrade, feeConfig)
    || resolveTradeCostBasisPerShare(poolTrade, feeConfig)
    || null;

  const unsettled = participations.filter((p) => !p.get('isSettled'));
  if (!unsettled.length) return [];

  const prefetchedInvestments = await prefetchInvestmentsById(unsettled);
  const results = [];

  for (const participation of unsettled) {
    const participationInvestmentId = String(participation.get('investmentId') || '').trim();
    const prefetched = participationInvestmentId
      ? prefetchedInvestments.get(participationInvestmentId)
      : null;
    const investment = prefetched || await findInvestment(participation.get('investmentId'), participation, poolTrade);
    if (!investment) continue;

    const investmentNumber = String(investment.get('investmentNumber') || '').trim();
    const investorId = investment.get('investorId');
    if (!investorId) continue;
    const status = String(investment.get('status') || '');
    if (status === 'completed' || status === 'cancelled') continue;

    const investmentCapital = Number(investment.get('amount') || investment.get('currentValue') || 0);
    const resolvedCommissionRates = await commissionRateResolver.resolve({
      traderId,
      investorId,
      investment,
    });
    const legDelta = computeInvestorPartialSellDelta({
      investmentCapital,
      costBasisPerShare,
      tradeBuyPrice,
      tradeSellPrice,
      sellFraction,
      traderBuyQuantity: buyQuantity,
      traderSoldBefore: previousSellQty,
      traderSoldAfter: currentSellQty,
      commissionRate: resolvedCommissionRates.totalRate,
      feeConfig,
    });
    if (!legDelta) continue;

    const {
      buyLeg,
      sellLeg,
      grossProfit: grossProfitDelta,
      commission: commissionDelta,
      netProfit: netProfitDelta,
      investorSellCashDelta,
      investorCostDelta,
    } = legDelta;

    const poolCapitalReleased = round2(buyLeg?.amount ?? investorCostDelta ?? 0);
    if (poolCapitalReleased <= 0) continue;

    const row = await bookPartialSellEscrowForInvestor({
      investorId,
      investment,
      investmentNumber,
      poolTrade,
      tradeNumber,
      sellOrderId,
      poolCapitalReleased,
      sellLeg,
      grossProfitDelta,
      netProfitDelta,
      commissionDelta,
      investorSellCashDelta,
      businessCaseId,
    });
    if (row) results.push(row);
  }

  return results;
}

async function bookInvestorPartialRealizationDeltaIfAny({ trade, previousTrade }) {
  if (!trade || !previousTrade) return null;

  const poolCtx = await resolvePoolContextForTraderSell(trade);
  if (!poolCtx) return null;

  const { traderTrade } = poolCtx;
  const newSellOrders = sortSellOrdersChronologically(getSellOrdersAddedSince(previousTrade, traderTrade));
  if (!newSellOrders.length) return null;

  const priorPrefix = getOrderArrayFromTradeLike(previousTrade);
  const combined = [];
  let rollingPrevious = previousTrade;
  const allResults = [];

  for (const sellOrder of newSellOrders) {
    combined.push(sellOrder);
    const soldQuantity = round2(
      [...priorPrefix, ...combined].reduce((sum, order) => sum + Number(order?.quantity || 0), 0),
    );
    const current = tradeSnapshotForPartialReplay(traderTrade, {
      sellOrders: [...priorPrefix, ...combined],
      soldQuantity,
    });
    const batch = await bookInvestorPartialRealizationForSellOrderDelta({
      poolCtx,
      previousTrade: rollingPrevious,
      trade: current,
      sellOrder,
    });
    if (batch.length) allResults.push(...batch);
    rollingPrevious = current;
  }

  return allResults.length ? allResults : null;
}

/**
 * Repair: investorPartialSellInternal belege without matching PTR→PPS (1592→1593) escrow legs.
 */
async function repairPartialSellEscrowGapsForPoolTrade(poolTradeId, { dryRun = false } = {}) {
  const tradeKey = String(poolTradeId || '').trim();
  if (!tradeKey) return { repaired: [], skipped: [], dryRun: !!dryRun };

  const belege = await new Parse.Query('Document')
    .equalTo('type', 'investorPartialSellInternal')
    .equalTo('tradeId', tradeKey)
    .equalTo('source', 'backend')
    .limit(500)
    .find({ useMasterKey: true });

  const repaired = [];
  const skipped = [];

  for (const beleg of belege) {
    const investmentId = beleg.get('investmentId');
    const meta = beleg.get('metadata') || {};
    const sellOrderId = String(meta.sellOrderId || '').trim();
    const poolCapitalReleased = round2(Number(meta.poolCapitalReleased || meta.betrag || 0));
    if (!investmentId || !sellOrderId || poolCapitalReleased <= 0) {
      skipped.push({ investmentId, sellOrderId, reason: 'incomplete_beleg' });
      continue;
    }

    const releaseBooked = await hasEscrowLeg(investmentId, 'partialSellRelease', {
      tradeId: tradeKey,
      sellOrderId,
    });
    if (releaseBooked) {
      skipped.push({ investmentId, sellOrderId, reason: 'already_booked' });
      continue;
    }

    if (dryRun) {
      repaired.push({ investmentId, sellOrderId, poolCapitalReleased, dryRun: true });
      continue;
    }

    const investment = await new Parse.Query('Investment').get(investmentId, { useMasterKey: true });
    const investorId = investment.get('investorId');
    const investmentNumber = investment.get('investmentNumber') || '';
    const trade = await new Parse.Query('Trade').get(tradeKey, { useMasterKey: true });
    const tradeNumber = trade.get('tradeNumber') || '';
    const businessCaseId = String(beleg.get('businessCaseId') || trade.get('businessCaseId') || '').trim();
    const internalBelegRef = resolveDocumentReference(beleg, { context: 'partial_sell_internal_beleg' });

    await bookPartialSellPoolRelease({
      investorId,
      investmentId,
      investmentNumber,
      tradeId: tradeKey,
      tradeNumber,
      sellOrderId,
      poolCapitalReleased,
      businessCaseId,
      internalBelegRef,
    });

    const grossProfit = round2(Math.max(0, Number(meta.grossProfit) || 0));
    if (grossProfit > 0) {
      const profitBooked = await hasEscrowLeg(investmentId, 'partialSellProfitRecognition', {
        tradeId: tradeKey,
        sellOrderId,
      });
      if (!profitBooked) {
        await bookPartialSellProfitRecognition({
          investorId,
          investmentId,
          investmentNumber,
          tradeId: tradeKey,
          tradeNumber,
          sellOrderId,
          grossProfit,
          businessCaseId,
          internalBelegRef,
        });
      }
    }

    repaired.push({ investmentId, sellOrderId, poolCapitalReleased });
  }

  return { tradeId: tradeKey, repaired, skipped, dryRun: !!dryRun };
}

async function repairPartialSellEscrowGapsForTraderLeg(traderTrade, options = {}) {
  const poolCtx = await resolvePoolContextForTraderSell(traderTrade);
  if (!poolCtx?.poolTrade?.id) {
    return { replayed: [], gaps: { repaired: [], skipped: [] } };
  }
  const replayed = await ensureInvestorPartialSellDeltasForTraderLeg(traderTrade);
  const gaps = await repairPartialSellEscrowGapsForPoolTrade(poolCtx.poolTrade.id, options);
  return { traderTradeId: traderTrade.id, poolTradeId: poolCtx.poolTrade.id, replayed, gaps };
}

module.exports = {
  bookInvestorPartialRealizationDeltaIfAny,
  ensureInvestorPartialSellDeltasForTraderLeg,
  repairPartialSellEscrowGapsForPoolTrade,
  repairPartialSellEscrowGapsForTraderLeg,
};
