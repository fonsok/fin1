'use strict';

const { round2 } = require('../../utils/accountingHelper/shared');

function sumMirrorBuyFromParticipationSnapshots(parts) {
  let poolPieces = 0;
  let poolCapital = 0;
  for (const p of parts || []) {
    const snap = p.get ? p.get('buySnapshot') : p.buySnapshot;
    if (!(snap?.poolPieces > 0)) continue;
    poolPieces += Number(snap.poolPieces);
    poolCapital += Number(snap.poolCapitalAllocated || 0);
  }
  return {
    poolPieces,
    poolCapitalAllocated: round2(poolCapital),
    participationCount: (parts || []).length,
  };
}

function inspectMirrorTradeBuyAlignment(trade, parts) {
  const { poolPieces, poolCapitalAllocated, participationCount } = sumMirrorBuyFromParticipationSnapshots(parts);
  if (!(poolPieces > 0)) {
    return {
      aligned: false,
      reason: participationCount > 0 ? 'no_snapshots' : 'no_participations',
      poolPieces: 0,
      poolCapitalAllocated: 0,
      participationCount,
    };
  }

  const currentQty = Number(trade.get('quantity') || 0);
  const currentBuyAmt = round2(Number(trade.get('buyAmount') || 0));
  const aligned = currentQty === poolPieces && Math.abs(currentBuyAmt - poolCapitalAllocated) < 0.02;

  return {
    aligned,
    reason: aligned ? 'already_aligned' : 'drift',
    poolPieces,
    poolCapitalAllocated,
    participationCount,
    currentQuantity: currentQty,
    currentBuyAmount: currentBuyAmt,
    quantityDelta: poolPieces - currentQty,
    buyAmountDelta: round2(poolCapitalAllocated - currentBuyAmt),
  };
}

async function syncMirrorBuyOrderRecordFromTrade(trade, { poolPieces, poolCapital }) {
  const buyOrderId = String(trade.get('buyOrderId') || '').trim();
  if (!buyOrderId) return { synced: false, reason: 'no_buy_order_id' };

  let order;
  try {
    order = await new Parse.Query('Order').get(buyOrderId, { useMasterKey: true });
  } catch (_) {
    return { synced: false, reason: 'buy_order_not_found' };
  }

  const currentQty = Number(order.get('executedQuantity') || order.get('quantity') || 0);
  const currentAmt = round2(Number(order.get('grossAmount') || order.get('totalAmount') || 0));
  const targetAmt = poolCapital > 0 ? poolCapital : currentAmt;
  if (currentQty === poolPieces && Math.abs(currentAmt - targetAmt) < 0.02) {
    return { synced: false, reason: 'already_aligned', orderId: order.id };
  }

  order.set('quantity', poolPieces);
  order.set('executedQuantity', poolPieces);
  if (poolCapital > 0) {
    order.set('grossAmount', poolCapital);
    order.set('totalAmount', poolCapital);
  }
  await order.save(null, { useMasterKey: true });
  return { synced: true, orderId: order.id, poolPieces, poolCapital: targetAmt };
}

/**
 * Idempotent safety net after pool activation — primary SSOT is
 * `resolveMirrorPoolBuyQuantity.applyResolvedMirrorPoolBuyQuantityToOrder` before mirror leg executes.
 */
async function syncMirrorTradeBuyFromParticipationSnapshots(trade) {
  if (!trade?.id) return { synced: false, reason: 'missing_trade' };

  const parts = await new Parse.Query('PoolTradeParticipation')
    .equalTo('tradeId', trade.id)
    .limit(500)
    .find({ useMasterKey: true });
  if (!parts.length) return { synced: false, reason: 'no_participations' };

  const inspection = inspectMirrorTradeBuyAlignment(trade, parts);
  if (inspection.reason === 'no_snapshots') {
    return { synced: false, reason: 'no_snapshots' };
  }
  if (inspection.aligned) {
    return { synced: false, reason: 'already_aligned', poolPieces: inspection.poolPieces };
  }

  const { poolPieces, poolCapitalAllocated: poolCapital } = inspection;
  trade.set('quantity', poolPieces);
  trade.set('remainingQuantity', poolPieces);
  if (poolCapital > 0) {
    trade.set('buyAmount', poolCapital);
  }

  const buyOrder = trade.get('buyOrder');
  if (buyOrder && typeof buyOrder === 'object') {
    const next = { ...buyOrder, quantity: poolPieces };
    if (poolCapital > 0) {
      next.totalAmount = poolCapital;
      next.grossAmount = poolCapital;
    }
    trade.set('buyOrder', next);
  }

  await trade.save(null, { useMasterKey: true });
  const orderSync = await syncMirrorBuyOrderRecordFromTrade(trade, { poolPieces, poolCapital });
  return { synced: true, poolPieces, poolCapital, orderSync };
}

module.exports = {
  sumMirrorBuyFromParticipationSnapshots,
  inspectMirrorTradeBuyAlignment,
  syncMirrorBuyOrderRecordFromTrade,
  syncMirrorTradeBuyFromParticipationSnapshots,
};
