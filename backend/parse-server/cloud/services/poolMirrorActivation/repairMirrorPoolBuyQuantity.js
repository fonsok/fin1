'use strict';

const { audit } = require('../../utils/structuredLogger');
const { getTraderTradeForPairedMirrorLeg } = require('../../utils/pairedTradeMirrorSync');
const { syncMirrorPoolSellProgressFromTraderLeg } = require('../../utils/pairedTradeMirrorSync/sellSync');
const {
  inspectMirrorTradeBuyAlignment,
  syncMirrorTradeBuyFromParticipationSnapshots,
} = require('./syncMirrorTradeBuyFromSnapshots');

function isMirrorPoolTrade(trade) {
  return String(trade?.get?.('buyLegType') || '').toUpperCase() === 'MIRROR_POOL';
}

async function loadParticipationsForTrade(tradeId) {
  return new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', tradeId)
    .limit(500)
    .find({ useMasterKey: true });
}

async function inspectMirrorPoolBuyDrift(trade) {
  if (!trade?.id) return { drift: false, reason: 'missing_trade' };
  if (!isMirrorPoolTrade(trade)) return { drift: false, reason: 'not_mirror_pool_trade' };

  const parts = await loadParticipationsForTrade(trade.id);
  const inspection = inspectMirrorTradeBuyAlignment(trade, parts);
  return {
    mirrorTradeId: trade.id,
    tradeNumber: trade.get('tradeNumber') || null,
    pairExecutionId: trade.get('pairExecutionId') || null,
    drift: !inspection.aligned && inspection.reason === 'drift',
    ...inspection,
  };
}

async function repairMirrorPoolBuyQuantityForTrade(mirrorTradeId, options = {}) {
  const dryRun = options.dryRun !== false;
  const resyncSellFromTrader = options.resyncSellFromTrader !== false;

  let trade;
  try {
    trade = await new Parse.Query('Trade').get(String(mirrorTradeId).trim(), { useMasterKey: true });
  } catch (_) {
    return { dryRun, repaired: false, reason: 'trade_not_found', mirrorTradeId };
  }

  const inspection = await inspectMirrorPoolBuyDrift(trade);
  if (inspection.reason === 'not_mirror_pool_trade') {
    return { dryRun, repaired: false, ...inspection };
  }
  if (inspection.reason === 'no_participations' || inspection.reason === 'no_snapshots') {
    return { dryRun, repaired: false, ...inspection };
  }
  if (inspection.aligned) {
    return { dryRun, repaired: false, ...inspection };
  }

  const preview = {
    dryRun,
    repaired: false,
    wouldRepair: true,
    ...inspection,
  };

  if (dryRun) {
    audit.info('poolMirror.repair.buyQuantity.dryRun', preview);
    return preview;
  }

  const syncResult = await syncMirrorTradeBuyFromParticipationSnapshots(trade);
  if (!syncResult.synced) {
    return { dryRun, repaired: false, ...inspection, syncResult };
  }

  let sellResync = null;
  if (resyncSellFromTrader) {
    const traderTrade = await getTraderTradeForPairedMirrorLeg(trade);
    const traderSold = Number(traderTrade?.get?.('soldQuantity') || 0);
    if (traderTrade?.id && traderSold > 0) {
      await syncMirrorPoolSellProgressFromTraderLeg(traderTrade);
      sellResync = { traderTradeId: traderTrade.id, traderSold };
    }
  }

  const result = {
    dryRun,
    repaired: true,
    mirrorTradeId: trade.id,
    tradeNumber: trade.get('tradeNumber') || null,
    poolPieces: syncResult.poolPieces,
    poolCapital: syncResult.poolCapital,
    orderSync: syncResult.orderSync || null,
    sellResync,
  };
  audit.info('poolMirror.repair.buyQuantity.applied', result);
  return result;
}

async function repairMirrorPoolBuyQuantityBatch(options = {}) {
  const dryRun = options.dryRun !== false;
  const limit = Math.min(200, Math.max(1, parseInt(options.limit, 10) || 50));
  const resyncSellFromTrader = options.resyncSellFromTrader !== false;
  const mirrorTradeId = String(options.mirrorTradeId || options.poolTradeId || '').trim();
  const pairExecutionId = String(options.pairExecutionId || '').trim();

  if (mirrorTradeId) {
    const single = await repairMirrorPoolBuyQuantityForTrade(mirrorTradeId, {
      dryRun,
      resyncSellFromTrader,
    });
    return {
      dryRun,
      scanned: 1,
      driftCount: single.drift || single.wouldRepair ? 1 : 0,
      repairedCount: single.repaired ? 1 : 0,
      results: [single],
    };
  }

  const q = new Parse.Query('Trade');
  q.equalTo('buyLegType', 'MIRROR_POOL');
  if (pairExecutionId) {
    q.equalTo('pairExecutionId', pairExecutionId);
  }
  q.ascending('createdAt');
  q.limit(limit);

  const trades = await q.find({ useMasterKey: true });
  const results = [];
  let driftCount = 0;
  let repairedCount = 0;

  for (const trade of trades) {
    const inspection = await inspectMirrorPoolBuyDrift(trade);
    if (inspection.drift) driftCount += 1;

    if (!inspection.drift) {
      results.push({ dryRun, repaired: false, ...inspection });
      continue;
    }

    const row = await repairMirrorPoolBuyQuantityForTrade(trade.id, {
      dryRun,
      resyncSellFromTrader,
    });
    if (row.repaired) repairedCount += 1;
    results.push(row);
  }

  return {
    dryRun,
    scanned: trades.length,
    driftCount,
    repairedCount,
    results,
  };
}

module.exports = {
  isMirrorPoolTrade,
  inspectMirrorPoolBuyDrift,
  repairMirrorPoolBuyQuantityForTrade,
  repairMirrorPoolBuyQuantityBatch,
};
