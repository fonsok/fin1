'use strict';

const { loadConfig } = require('../configHelper/index.js');
const { round2 } = require('../accountingHelper/shared');
const { totalSellQuantity } = require('../../triggers/tradeSellQuantityHelpers');
const { computePoolPiecesForMirrorTrade } = require('../poolMirrorQueries');
const {
  TRADER_FULL_SELL_EPSILON,
  resolvePoolSoldQtyCumulative,
} = require('../poolMirrorEconomics/traderSellMath');
const { getMirrorTradeForPairedTraderLeg } = require('./legResolution');

function totalSellAmountFromOrders(orders) {
  return orders.reduce((s, o) => s + Number(o?.totalAmount || 0), 0);
}

async function applyMirrorSellSyncFromTraderLeg(traderTrade, mirrorTrade, { skipIfComplete = false } = {}) {
  if (!traderTrade || !mirrorTrade) return;

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

  const config = await loadConfig();
  const feeConfig = config.financial || {};
  const poolPieces = await computePoolPiecesForMirrorTrade(mirrorTrade, buyPrice, feeConfig);
  const traderSold = Number(traderTrade.get('soldQuantity') || 0) || totalSellQuantity(traderTrade);
  const traderFullySold = traderSold >= qT - TRADER_FULL_SELL_EPSILON;
  const buyMirrorQtyEarly = poolPieces > 0 ? poolPieces : Number(mirrorTrade.get('quantity') || qM);

  if (skipIfComplete) {
    const targetSold = poolPieces > 0
      ? resolvePoolSoldQtyCumulative(poolPieces, traderSold, qT)
      : resolvePoolSoldQtyCumulative(buyMirrorQtyEarly, traderSold, qT);
    const currentSold = Number(mirrorTrade.get('soldQuantity') || 0) || totalSellQuantity(mirrorTrade);
    if (
      String(mirrorTrade.get('status') || '') === 'completed'
      && Math.abs(currentSold - targetSold) < 0.01
    ) {
      return;
    }
  }

  let ratio = qM / qT;
  if (poolPieces > 0) {
    const poolSoldTarget = resolvePoolSoldQtyCumulative(poolPieces, traderSold, qT);
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
    const targetSold = resolvePoolSoldQtyCumulative(poolPieces, traderSold, qT);
    const driftQty = round2(targetSold - sumQty);
    if (scaled.length && Number.isFinite(driftQty) && Math.abs(driftQty) >= 1e-6) {
      const last = scaled[scaled.length - 1];
      last.quantity = round2(Math.max(0, Number(last.quantity || 0) + driftQty));
      sumQty = scaled.reduce((s, o) => s + Number(o.quantity || 0), 0);
    }
    if (traderFullySold && sumQty < poolPieces) {
      const remainder = round2(poolPieces - sumQty);
      if (scaled.length && remainder > 0) {
        const last = scaled[scaled.length - 1];
        last.quantity = round2(Number(last.quantity || 0) + remainder);
        sumQty = poolPieces;
      }
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

  let soldQty = sumQty;
  if (traderFullySold && poolPieces > 0) {
    soldQty = poolPieces;
  }
  mirrorTrade.set('soldQuantity', soldQty);

  if (buyMirrorQty > 0 && (traderFullySold || Math.abs(soldQty - buyMirrorQty) < 0.02)) {
    mirrorTrade.set('status', 'completed');
    mirrorTrade.set('closedAt', new Date());
  }

  // Kaufseite (quantity, buyAmount, buyOrder) bleibt unverändert — GOBD / immutable Buy-Leg.
  // Nur Verkaufsfelder (sellOrders, soldQuantity, profit) werden vom Trader-Leg gespiegelt.

  const { refreshPoolMirrorLegEconomicsPersistence } = require('../poolMirrorEconomics/persistTradeLegEconomics');
  await refreshPoolMirrorLegEconomicsPersistence(mirrorTrade, { traderReference: null });
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

async function syncMirrorPoolSellProgressFromTraderLeg(traderTrade) {
  const mirrorTrade = await getMirrorTradeForPairedTraderLeg(traderTrade);
  if (!mirrorTrade) return;
  await applyMirrorSellSyncFromTraderLeg(traderTrade, mirrorTrade, { skipIfComplete: false });
}

module.exports = {
  applyMirrorSellSyncFromTraderLeg,
  syncMirrorTradeWhenTraderLegCompletes,
  syncMirrorPoolSellProgressFromTraderLeg,
};
