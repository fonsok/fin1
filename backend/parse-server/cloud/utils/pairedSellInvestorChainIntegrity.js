'use strict';

const { getMirrorTradeForPairedTraderLeg } = require('./pairedTradeMirrorSync');
const { totalSellQuantity } = require('../triggers/tradeSellQuantityHelpers');

const COLLECTION_BILL_TYPES = ['investorCollectionBill', 'investor_collection_bill'];

/**
 * Mirror exit economics live on Trade.sellOrders — not a MIRROR_POOL Order row (paired-buy SSOT).
 */
function mirrorTradeHasSyncedExitEconomics(trade) {
  if (!trade || typeof trade.get !== 'function') return false;
  const sells = trade.get('sellOrders') || [];
  if (Array.isArray(sells) && sells.length > 0) return true;
  if (trade.get('sellOrder')) return true;
  const exitPx = Number(trade.get('exitPrice') || trade.get('sellPrice') || 0);
  if (Number.isFinite(exitPx) && exitPx > 0) return true;
  const sellAmt = Number(trade.get('sellAmount') || 0);
  if (Number.isFinite(sellAmt) && sellAmt > 0) return true;
  const gp = Number(trade.get('grossProfit') || trade.get('calculatedProfit') || 0);
  return Number.isFinite(gp) && gp !== 0;
}

function traderTradeHasSellActivity(traderTrade) {
  const sold = Number(traderTrade.get('soldQuantity') || 0) || totalSellQuantity(traderTrade);
  return sold > 0 || String(traderTrade.get('status') || '') === 'completed';
}

/**
 * Evaluate paired buy → sell → investor bill chain for one TRADER/MIRROR trade pair.
 * @returns {{ ok: boolean, phase: string, issues: string[], metrics: object }}
 */
async function evaluatePairedSellInvestorChain({ traderTrade, mirrorTrade }) {
  const issues = [];
  const metrics = {
    pairExecutionId: traderTrade.get('pairExecutionId') || null,
    traderTradeId: traderTrade.id,
    traderTradeNumber: traderTrade.get('tradeNumber') || null,
    mirrorTradeId: mirrorTrade?.id || null,
    mirrorTradeNumber: mirrorTrade?.get('tradeNumber') || null,
  };

  if (!mirrorTrade?.id) {
    return {
      ok: false,
      phase: 'buy',
      issues: ['mirror_trade_missing'],
      metrics,
    };
  }

  const participationCount = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', mirrorTrade.id)
    .count({ useMasterKey: true });
  metrics.participationCount = participationCount;

  if (participationCount === 0) {
    issues.push('mirror_pool_not_activated');
  }

  const traderParts = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', traderTrade.id)
    .count({ useMasterKey: true });
  if (traderParts > 0) {
    issues.push('trader_leg_has_pool_participations');
  }

  if (!traderTradeHasSellActivity(traderTrade)) {
    return {
      ok: issues.length === 0,
      phase: 'open',
      issues,
      metrics: { ...metrics, sellPhase: 'skipped_open_position' },
    };
  }

  metrics.traderSoldQuantity = Number(traderTrade.get('soldQuantity') || 0) || totalSellQuantity(traderTrade);
  metrics.mirrorSoldQuantity = Number(mirrorTrade.get('soldQuantity') || 0) || totalSellQuantity(mirrorTrade);

  if (!mirrorTradeHasSyncedExitEconomics(mirrorTrade)) {
    issues.push('mirror_trade_missing_sell_economics');
  }

  const retryJob = await new Parse.Query('SettlementRetryJob')
    .equalTo('tradeId', traderTrade.id)
    .containedIn('status', ['pending', 'processing', 'failed'])
    .descending('updatedAt')
    .first({ useMasterKey: true });

  if (retryJob) {
    const err = String(retryJob.get('lastError') || '').trim();
    metrics.settlementRetry = {
      jobId: retryJob.id,
      status: retryJob.get('status'),
      lastError: err || null,
    };
    issues.push(err ? 'settlement_retry_blocked' : 'settlement_retry_pending');
  }

  const participations = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', mirrorTrade.id)
    .limit(500)
    .find({ useMasterKey: true });

  const unsettled = participations.filter((p) => p.get('isSettled') !== true);
  metrics.unsettledParticipationCount = unsettled.length;
  if (participationCount > 0 && unsettled.length > 0) {
    issues.push('participations_not_settled');
  }

  const billQuery = new Parse.Query('Document');
  billQuery.equalTo('tradeId', mirrorTrade.id);
  billQuery.containedIn('type', COLLECTION_BILL_TYPES);
  billQuery.equalTo('source', 'backend');
  const collectionBillCount = await billQuery.count({ useMasterKey: true });
  metrics.collectionBillCount = collectionBillCount;

  if (participationCount > 0 && collectionBillCount < participationCount) {
    issues.push('investor_collection_bills_incomplete');
  }

  return {
    ok: issues.length === 0,
    phase: 'sell_settled',
    issues,
    metrics,
  };
}

/**
 * Scan recent completed TRADER paired legs (+ open pairs with participations).
 */
async function scanPairedSellInvestorChainIntegrity({ limit = 25 } = {}) {
  const cap = Math.max(1, Math.min(100, Number(limit) || 25));

  const traderTrades = await new Parse.Query('Trade')
    .equalTo('buyLegType', 'TRADER')
    .exists('pairExecutionId')
    .descending('updatedAt')
    .limit(cap)
    .find({ useMasterKey: true });

  const violations = [];
  let checkedPairs = 0;
  let openPositions = 0;
  let sellSettledHealthy = 0;

  for (const traderTrade of traderTrades) {
    const mirrorTrade = await getMirrorTradeForPairedTraderLeg(traderTrade);
    if (!mirrorTrade) continue;

    const mirrorQty = Number(mirrorTrade.get('quantity') || mirrorTrade.get('buyOrder')?.quantity || 0);
    if (mirrorQty <= 0) continue;

    checkedPairs += 1;
    const result = await evaluatePairedSellInvestorChain({ traderTrade, mirrorTrade });
    if (result.phase === 'open') {
      openPositions += 1;
      if (!result.ok) violations.push(result);
      continue;
    }
    if (result.ok) {
      sellSettledHealthy += 1;
    } else {
      violations.push(result);
    }
  }

  const retryBlocked = await new Parse.Query('SettlementRetryJob')
    .equalTo('kind', 'trade_settlement')
    .containedIn('status', ['pending', 'failed'])
    .exists('lastError')
    .limit(25)
    .find({ useMasterKey: true });

  const blockedSamples = [];
  for (const j of retryBlocked) {
    const lastError = String(j.get('lastError') || '').trim();
    if (!lastError) continue;
    const tradeId = String(j.get('tradeId') || '').trim();
    let tradeExists = false;
    if (tradeId) {
      try {
        await new Parse.Query('Trade').get(tradeId, { useMasterKey: true });
        tradeExists = true;
      } catch (_) {
        tradeExists = false;
      }
    }
    if (!tradeExists) continue;
    blockedSamples.push({
      jobId: j.id,
      tradeId,
      status: j.get('status'),
      lastError,
    });
  }

  const overall = violations.length > 0 || blockedSamples.length > 0 ? 'degraded' : 'healthy';

  return {
    overall,
    checkedPairs,
    openPositions,
    sellSettledHealthy,
    violationCount: violations.length,
    settlementRetryBlockedCount: blockedSamples.length,
    violations: violations.slice(0, 30),
    settlementRetryBlockedSamples: blockedSamples.slice(0, 10),
    message: overall === 'healthy'
      ? 'Paired sell → investor bill chain OK'
      : `${violations.length} paired chain violation(s); ${blockedSamples.length} blocked settlement retry job(s)`,
  };
}

module.exports = {
  mirrorTradeHasSyncedExitEconomics,
  traderTradeHasSellActivity,
  evaluatePairedSellInvestorChain,
  scanPairedSellInvestorChainIntegrity,
};
