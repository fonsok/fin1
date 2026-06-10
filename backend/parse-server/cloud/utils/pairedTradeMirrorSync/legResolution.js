'use strict';

/**
 * Resolve TRADER ↔ MIRROR_POOL trade pairs for executePairedBuy.
 */

function mirrorPoolTradeHasSyncedExitEconomics(mirrorTrade) {
  if (!mirrorTrade || typeof mirrorTrade.get !== 'function') return false;
  const sells = mirrorTrade.get('sellOrders') || [];
  if (Array.isArray(sells) && sells.length > 0) return true;
  if (mirrorTrade.get('sellOrder')) return true;
  const exitPx = Number(mirrorTrade.get('exitPrice') || mirrorTrade.get('sellPrice') || 0);
  if (Number.isFinite(exitPx) && exitPx > 0) return true;
  const sellAmt = Number(mirrorTrade.get('sellAmount') || 0);
  if (Number.isFinite(sellAmt) && sellAmt > 0) return true;
  const gp = Number(mirrorTrade.get('grossProfit') || mirrorTrade.get('calculatedProfit') || 0);
  return Number.isFinite(gp) && gp !== 0;
}

async function getTraderTradeForPairedMirrorLeg(mirrorTrade) {
  const buyOrderId = mirrorTrade.get('buyOrderId');
  if (!buyOrderId) return null;

  let mirrorBuyOrder;
  try {
    mirrorBuyOrder = await new Parse.Query('Order').get(buyOrderId, { useMasterKey: true });
  } catch (_) {
    return null;
  }

  const pairId = mirrorBuyOrder.get('pairExecutionId');
  if (!pairId) return null;
  if (String(mirrorBuyOrder.get('legType') || '').toUpperCase() !== 'MIRROR_POOL') return null;

  const traderBuyOrder = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairId)
    .equalTo('legType', 'TRADER')
    .first({ useMasterKey: true });

  if (!traderBuyOrder) return null;

  const traderTradeId = traderBuyOrder.get('tradeId');
  if (!traderTradeId || traderTradeId === mirrorTrade.id) return null;

  const Trade = Parse.Object.extend('Trade');
  try {
    return await new Parse.Query(Trade).get(traderTradeId, { useMasterKey: true });
  } catch (_) {
    return null;
  }
}

async function getMirrorTradeForPairedTraderLeg(traderTrade) {
  const buyOrderId = traderTrade.get('buyOrderId');
  if (!buyOrderId) return null;

  let traderBuyOrder;
  try {
    traderBuyOrder = await new Parse.Query('Order').get(buyOrderId, { useMasterKey: true });
  } catch (_) {
    return null;
  }

  const pairId = traderBuyOrder.get('pairExecutionId');
  if (!pairId) return null;
  if (String(traderBuyOrder.get('legType') || '').toUpperCase() !== 'TRADER') return null;

  const mirrorBuyOrder = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairId)
    .equalTo('legType', 'MIRROR_POOL')
    .first({ useMasterKey: true });

  if (!mirrorBuyOrder) return null;

  const mirrorTradeId = mirrorBuyOrder.get('tradeId');
  if (!mirrorTradeId || mirrorTradeId === traderTrade.id) return null;

  const Trade = Parse.Object.extend('Trade');
  try {
    return await new Parse.Query(Trade).get(mirrorTradeId, { useMasterKey: true });
  } catch (_) {
    return null;
  }
}

async function isPairedTraderLegTrade(trade) {
  const buyOrderId = trade.get('buyOrderId');
  if (!buyOrderId) return false;
  try {
    const o = await new Parse.Query('Order').get(buyOrderId, { useMasterKey: true });
    if (!o.get('pairExecutionId')) return false;
    return String(o.get('legType') || '').toUpperCase() === 'TRADER';
  } catch (_) {
    return false;
  }
}

module.exports = {
  mirrorPoolTradeHasSyncedExitEconomics,
  getTraderTradeForPairedMirrorLeg,
  getMirrorTradeForPairedTraderLeg,
  isPairedTraderLegTrade,
};
