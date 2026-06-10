'use strict';

const { getTraderCommissionRate, loadConfig } = require('../../configHelper/index.js');
const { round2, resolveSettlementLegPrices } = require('../shared');
const {
  isPairedTraderLegTrade,
  getMirrorTradeForPairedTraderLeg,
  syncMirrorPoolSellProgressFromTraderLeg,
  syncMirrorTradeWhenTraderLegCompletes,
  mirrorPoolTradeHasSyncedExitEconomics,
} = require('../../pairedTradeMirrorSync');
const { computeTradingFeesWithBreakdown } = require('../settlementTradeMath');
const { ensureParticipationsForTrade } = require('../settlementInvestmentFallback');
const {
  ensureAllPoolMirrorSellEigenbelegeForTraderLeg,
} = require('../poolMirrorExecutionEigenbelegBook');
const {
  ensureInvestorPartialSellDeltasForTraderLeg,
} = require('../settlementInvestorPartialRealization');
const { audit } = require('../../structuredLogger');

async function loadParticipationsAndPoolTrade({
  trade,
  initialPoolTrade,
  invokedOnMirrorLeg,
  lifecycleTradeNumber,
  netTradingProfit,
}) {
  let participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', initialPoolTrade.id)
    .find({ useMasterKey: true });

  let poolSettlementTrade = initialPoolTrade;
  let netTradingProfitForPool = netTradingProfit;
  let settlementTradeNumber = initialPoolTrade.get('tradeNumber') || lifecycleTradeNumber;

  if (participations.length === 0 && !invokedOnMirrorLeg) {
    const skipPoolFallback = await isPairedTraderLegTrade(trade);
    if (skipPoolFallback) {
      const mirrorTrade = await getMirrorTradeForPairedTraderLeg(trade);
      if (mirrorTrade) {
        participations = await new Parse.Query('PoolTradeParticipation')
          .equalTo('tradeId', mirrorTrade.id)
          .find({ useMasterKey: true });
        if (participations.length === 0) {
          participations = await ensureParticipationsForTrade(mirrorTrade);
        }
        if (participations.length > 0) {
          poolSettlementTrade = mirrorTrade;
          settlementTradeNumber = mirrorTrade.get('tradeNumber') || lifecycleTradeNumber;
          const mirrorGross = Number(mirrorTrade.get('grossProfit') || 0);
          const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(mirrorTrade);
          netTradingProfitForPool = round2(mirrorGross - mirrorFees);
        }
      }
    } else {
      participations = await ensureParticipationsForTrade(trade);
    }
  } else if (participations.length === 0 && invokedOnMirrorLeg) {
    participations = await ensureParticipationsForTrade(initialPoolTrade);
    if (participations.length > 0) {
      const mirrorGross = Number(initialPoolTrade.get('grossProfit') || 0);
      const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(initialPoolTrade);
      netTradingProfitForPool = round2(mirrorGross - mirrorFees);
    }
  } else if (invokedOnMirrorLeg) {
    const mirrorGross = Number(initialPoolTrade.get('grossProfit') || 0);
    const { totalFees: mirrorFees } = computeTradingFeesWithBreakdown(initialPoolTrade);
    netTradingProfitForPool = round2(mirrorGross - mirrorFees);
  }

  return {
    participations,
    poolSettlementTrade,
    netTradingProfitForPool,
    settlementTradeNumber,
  };
}

async function runPreSettlementMirrorHooks(trade, traderBookingTrade, invokedOnMirrorLeg) {
  if (!traderBookingTrade || invokedOnMirrorLeg) return;
  try {
    await ensureAllPoolMirrorSellEigenbelegeForTraderLeg(traderBookingTrade);
  } catch (err) {
    audit.warn('settlement.poolMirror.sellEigenbelegEnsure', {
      tradeId: trade.id,
      traderLegId: traderBookingTrade.id,
      error: err && err.message ? err.message : String(err),
      message: 'Pool-mirror sell eigenbeleg ensure before settlement failed (non-blocking)',
    });
  }
  try {
    await ensureInvestorPartialSellDeltasForTraderLeg(traderBookingTrade);
  } catch (err) {
    audit.warn('settlement.investor.partialSellEnsure', {
      tradeId: trade.id,
      traderLegId: traderBookingTrade.id,
      error: err && err.message ? err.message : String(err),
      message: 'Investor partial-sell delta ensure before settlement failed (non-blocking)',
    });
  }
}

async function syncPoolTradeBeforeSettlement({
  trade,
  poolSettlementTrade,
  traderLegForPool,
  netTradingProfitForPool,
}) {
  if (!traderLegForPool || mirrorPoolTradeHasSyncedExitEconomics(poolSettlementTrade)) {
    return { poolSettlementTrade, netTradingProfitForPool };
  }
  try {
    await syncMirrorPoolSellProgressFromTraderLeg(traderLegForPool);
    await syncMirrorTradeWhenTraderLegCompletes(traderLegForPool);
    const syncedPoolTrade = await new Parse.Query('Trade').get(poolSettlementTrade.id, { useMasterKey: true });
    const syncedGross = Number(syncedPoolTrade.get('grossProfit') || 0);
    const { totalFees: syncedFees } = computeTradingFeesWithBreakdown(syncedPoolTrade);
    return {
      poolSettlementTrade: syncedPoolTrade,
      netTradingProfitForPool: round2(syncedGross - syncedFees),
    };
  } catch (err) {
    audit.warn('settlement.poolMirror.syncBeforeSettle', {
      tradeId: trade.id,
      poolTradeId: poolSettlementTrade.id,
      traderLegId: traderLegForPool.id,
      error: err && err.message ? err.message : String(err),
      message: 'Mirror sell sync before settlement failed — using trader-leg price fallback',
    });
    return { poolSettlementTrade, netTradingProfitForPool };
  }
}

function applyTraderLegNetProfitFallback({
  poolSettlementTrade,
  traderLegForPool,
  netTradingProfitForPool,
}) {
  if (
    netTradingProfitForPool === 0
    && Number(poolSettlementTrade.get('grossProfit') || 0) === 0
    && traderLegForPool
  ) {
    const traderGross = Number(traderLegForPool.get('grossProfit') || 0);
    const { totalFees: traderFees } = computeTradingFeesWithBreakdown(traderLegForPool);
    const traderQty = Number(traderLegForPool.get('quantity') || 0);
    const poolQty = Number(poolSettlementTrade.get('quantity') || 0);
    const scale = traderQty > 0 ? poolQty / traderQty : 1;
    return round2((traderGross - traderFees) * scale);
  }
  return netTradingProfitForPool;
}

function resolvePoolLegPrices(poolSettlementTrade, traderLegForPool) {
  const { tradeBuyPrice, tradeSellPrice } = resolveSettlementLegPrices(
    poolSettlementTrade,
    traderLegForPool,
  );
  if (!(tradeSellPrice > 0)) {
    throw new Error(
      `GoB fail-closed: no sell price for pool settlement trade ${poolSettlementTrade.id} `
      + `(trader leg ${traderLegForPool?.id || 'n/a'})`,
    );
  }
  return { tradeBuyPrice, tradeSellPrice };
}

/**
 * Participation scope, mirror hooks, leg prices — everything before the participation loop.
 */
async function preparePoolSettlementScope({
  trade,
  traderBookingTrade,
  initialPoolTrade,
  invokedOnMirrorLeg,
  lifecycleTradeNumber,
  netTradingProfit,
}) {
  const participationScope = await loadParticipationsAndPoolTrade({
    trade,
    initialPoolTrade,
    invokedOnMirrorLeg,
    lifecycleTradeNumber,
    netTradingProfit,
  });

  if (participationScope.participations.length === 0) {
    return null;
  }

  await runPreSettlementMirrorHooks(trade, traderBookingTrade, invokedOnMirrorLeg);

  const traderLegForPool = traderBookingTrade
    && traderBookingTrade.id !== participationScope.poolSettlementTrade.id
    ? traderBookingTrade
    : null;

  const syncResult = await syncPoolTradeBeforeSettlement({
    trade,
    poolSettlementTrade: participationScope.poolSettlementTrade,
    traderLegForPool,
    netTradingProfitForPool: participationScope.netTradingProfitForPool,
  });

  const netTradingProfitForPool = applyTraderLegNetProfitFallback({
    poolSettlementTrade: syncResult.poolSettlementTrade,
    traderLegForPool,
    netTradingProfitForPool: syncResult.netTradingProfitForPool,
  });

  const { tradeBuyPrice, tradeSellPrice } = resolvePoolLegPrices(
    syncResult.poolSettlementTrade,
    traderLegForPool,
  );

  const commissionRate = await getTraderCommissionRate();
  const config = await loadConfig();

  return {
    participations: participationScope.participations,
    poolSettlementTrade: syncResult.poolSettlementTrade,
    settlementTradeNumber: participationScope.settlementTradeNumber,
    netTradingProfitForPool,
    tradeBuyPrice,
    tradeSellPrice,
    commissionRate,
    feeConfig: config.financial,
    taxConfig: config.tax || {},
  };
}

module.exports = {
  preparePoolSettlementScope,
};
