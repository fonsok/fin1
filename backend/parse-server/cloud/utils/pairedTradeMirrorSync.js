// ============================================================================
// Paired buy (executePairedBuy): pool participations attach to the MIRROR_POOL
// Trade, while the client typically completes the TRADER Trade first. Without
// syncing sell + completion onto the mirror Trade, settleAndDistribute never
// runs for participations → missing investor CollectionBills / statements and
// missing trader commission_credit tied to that pool exit.
// ============================================================================

'use strict';

const { loadConfig } = require('./configHelper/index.js');
const { round2 } = require('./accountingHelper/shared');
const { totalSellQuantity } = require('../triggers/tradeSellQuantityHelpers');
/**
 * True when mirror trade already has embedded exit / sell-side data.
 * If status is `completed` but this is false (e.g. race), we must still sync from
 * the trader leg — otherwise settleAndDistribute sees sell price 0 → no sellLeg
 * → buildCollectionBillBelegSnapshot throws and no investor CollectionBill is created.
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

/**
 * PoolTradeParticipation rows use the mirror Trade's id. Settlement must load participations
 * from this trade when the completed row is the TRADER leg of executePairedBuy.
 *
 * @param {Parse.Object} traderTrade
 * @returns {Promise<Parse.Object|null>} mirror Trade or null
 */
/**
 * Inverse of getMirrorTradeForPairedTraderLeg: TRADER trade for a MIRROR_POOL trade row.
 * @param {Parse.Object} mirrorTrade
 * @returns {Promise<Parse.Object|null>}
 */
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

/**
 * @param {Parse.Object} traderTrade — Trade whose buy leg is TRADER paired order
 */
async function applyMirrorSellSyncFromTraderLeg(traderTrade, mirrorTrade, { skipIfComplete = false } = {}) {
  if (!traderTrade || !mirrorTrade) return;

  if (
    skipIfComplete
    && String(mirrorTrade.get('status') || '') === 'completed'
    && mirrorPoolTradeHasSyncedExitEconomics(mirrorTrade)
  ) {
    return;
  }

  const buyOrderId = traderTrade.get('buyOrderId');
  let traderBuyOrder;
  try {
    traderBuyOrder = await new Parse.Query('Order').get(buyOrderId, { useMasterKey: true });
  } catch (_) {
    return;
  }

  const pairId = traderBuyOrder.get('pairExecutionId');
  const mirrorBuyOrder = await new Parse.Query('Order')
    .equalTo('pairExecutionId', pairId)
    .equalTo('legType', 'MIRROR_POOL')
    .first({ useMasterKey: true });
  if (!mirrorBuyOrder) return;

  const qT = Number(traderBuyOrder.get('executedQuantity') || traderBuyOrder.get('quantity') || 0);
  const qM = Number(mirrorBuyOrder.get('executedQuantity') || mirrorBuyOrder.get('quantity') || 0);
  if (!Number.isFinite(qT) || qT <= 0 || !Number.isFinite(qM) || qM <= 0) return;

  const buyPrice = Number(
    traderTrade.get('buyPrice')
    || traderBuyOrder.get('price')
    || mirrorTrade.get('buyPrice')
    || 0,
  );
  const {
    computePoolPiecesForMirrorTrade,
    poolSellQuantityForTraderSellFraction,
  } = require('./poolMirrorEconomics');

  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const poolPieces = await computePoolPiecesForMirrorTrade(mirrorTrade, buyPrice, feeConfig);
  const traderSold = Number(traderTrade.get('soldQuantity') || 0) || totalSellQuantity(traderTrade);
  const traderSellFraction = qT > 0 ? Math.min(1, traderSold / qT) : 0;

  let ratio = qM / qT;
  if (poolPieces > 0) {
    const poolSoldTarget = poolSellQuantityForTraderSellFraction(poolPieces, traderSellFraction);
    ratio = traderSold > 0 ? poolSoldTarget / traderSold : poolPieces / qT;
  }

  const sellOrders = traderTrade.get('sellOrders') || [];
  const sellOne = traderTrade.get('sellOrder');
  const sourceSells = sellOrders.length > 0 ? sellOrders : (sellOne ? [sellOne] : []);
  if (sourceSells.length === 0) return;

  const scaled = sourceSells.map((so) => {
    const base = so && typeof so === 'object' ? { ...so } : {};
    const qty = Number(base.quantity || 0) * ratio;
    const amt = Number(base.totalAmount || 0) * ratio;
    base.quantity = round2(qty);
    base.totalAmount = round2(amt);
    return base;
  });

  const buyMirrorQty = poolPieces > 0 ? poolPieces : Number(mirrorTrade.get('quantity') || qM);
  let sumQty = scaled.reduce((s, o) => s + Number(o.quantity || 0), 0);
  if (poolPieces > 0) {
    const targetSold = poolSellQuantityForTraderSellFraction(poolPieces, traderSellFraction);
    const driftQty = round2(targetSold - sumQty);
    if (scaled.length && Number.isFinite(driftQty) && Math.abs(driftQty) >= 1e-6) {
      const last = scaled[scaled.length - 1];
      last.quantity = round2(Math.max(0, Number(last.quantity || 0) + driftQty));
      sumQty = scaled.reduce((s, o) => s + Number(o.quantity || 0), 0);
    }
  } else {
    const driftQty = round2(buyMirrorQty - sumQty);
    if (scaled.length && Number.isFinite(driftQty) && Math.abs(driftQty) > 1e-6 && Math.abs(driftQty) < 2) {
      const last = scaled[scaled.length - 1];
      last.quantity = round2(Number(last.quantity || 0) + driftQty);
      sumQty = scaled.reduce((s, o) => s + Number(o.quantity || 0), 0);
    }
  }

  mirrorTrade.set('sellOrders', scaled);
  mirrorTrade.unset('sellOrder');

  const gp = Number(traderTrade.get('grossProfit') || 0) * ratio;
  const sa = Number(traderTrade.get('sellAmount') || totalSellAmountFromOrders(sourceSells)) * ratio;
  mirrorTrade.set('grossProfit', round2(gp));
  mirrorTrade.set('sellAmount', round2(sa));
  mirrorTrade.set('calculatedProfit', round2(gp));

  const buyAmt = Number(mirrorTrade.get('buyAmount') || 0);
  if (buyAmt > 0) {
    mirrorTrade.set('profitPercentage', round2((gp / buyAmt) * 100));
  }

  const soldQty = sumQty;
  mirrorTrade.set('soldQuantity', soldQty);

  if (buyMirrorQty > 0 && Math.abs(soldQty - buyMirrorQty) < 0.02) {
    mirrorTrade.set('status', 'completed');
    mirrorTrade.set('closedAt', new Date());
  }

  if (poolPieces > 0) {
    mirrorTrade.set('quantity', poolPieces);
    const buyPx = buyPrice > 0 ? buyPrice : Number(mirrorTrade.get('buyPrice') || 0);
    if (buyPx > 0) {
      mirrorTrade.set('buyAmount', round2(poolPieces * buyPx));
    }
  }

  await mirrorTrade.save(null, { useMasterKey: true });
  console.log(
    `✅ Paired buy: mirror trade #${mirrorTrade.get('tradeNumber')} synced from trader trade #${traderTrade.get('tradeNumber')} (pairExecutionId=${pairId}, poolPieces=${poolPieces || 'order-ratio'})`,
  );
}

async function syncMirrorTradeWhenTraderLegCompletes(traderTrade) {
  const mirrorTrade = await getMirrorTradeForPairedTraderLeg(traderTrade);
  if (!mirrorTrade) return;
  await applyMirrorSellSyncFromTraderLeg(traderTrade, mirrorTrade, { skipIfComplete: true });
}

/** Teilverkauf auf Trader-Leg: Pool-Mirror soldQuantity / sellOrders nachlegen. */
async function syncMirrorPoolSellProgressFromTraderLeg(traderTrade) {
  const mirrorTrade = await getMirrorTradeForPairedTraderLeg(traderTrade);
  if (!mirrorTrade) return;
  await applyMirrorSellSyncFromTraderLeg(traderTrade, mirrorTrade, { skipIfComplete: false });
}

function totalSellAmountFromOrders(orders) {
  return orders.reduce((s, o) => s + Number(o?.totalAmount || 0), 0);
}

/**
 * True when this Trade was opened from the TRADER buy leg of executePairedBuy.
 * PoolTradeParticipation rows always hang off the MIRROR_POOL trade — never call
 * ensureParticipationsForTrade fallback for this trade or we duplicate pool rows.
 */
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
  syncMirrorTradeWhenTraderLegCompletes,
  syncMirrorPoolSellProgressFromTraderLeg,
  applyMirrorSellSyncFromTraderLeg,
  isPairedTraderLegTrade,
  getMirrorTradeForPairedTraderLeg,
  getTraderTradeForPairedMirrorLeg,
};
