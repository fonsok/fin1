// ============================================================================
// Parse Cloud Code
// triggers/trade.js - Trade Triggers
// ============================================================================

'use strict';

const { getTraderCommissionRate } = require('../utils/configHelper/index.js');
const { settleAndDistribute } = require('../utils/accountingHelper');
const { calculateOrderFees } = require('../utils/helpers');

// ============================================================================
// BEFORE SAVE
// ============================================================================

Parse.Cloud.beforeSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !trade.existed();

  if (isNew) {
    if (!trade.get('tradeNumber')) {
      const lastTrade = await new Parse.Query('Trade')
        .descending('tradeNumber')
        .first({ useMasterKey: true });

      const nextNumber = lastTrade ? (lastTrade.get('tradeNumber') || 0) + 1 : 1;
      trade.set('tradeNumber', nextNumber);
    }

    if (!trade.get('status')) {
      trade.set('status', 'pending');
    }

    const buyOrder = trade.get('buyOrder');
    const directQuantity = trade.get('quantity');
    const quantity = directQuantity || (buyOrder ? buyOrder.quantity : 0);

    if (!trade.has('soldQuantity')) trade.set('soldQuantity', 0);
    if (!trade.has('remainingQuantity')) trade.set('remainingQuantity', quantity);

    const calculatedProfit = trade.get('calculatedProfit');
    if (calculatedProfit !== undefined && calculatedProfit !== null) {
      trade.set('grossProfit', calculatedProfit);

      const tradingFees = computeTradingFees(trade);
      trade.set('tradingFees', tradingFees);
      trade.set('totalFees', tradingFees);
      trade.set('netProfit', calculatedProfit - tradingFees);
      trade.set('profitPercentage', quantity > 0 ? (calculatedProfit / quantity) * 100 : 0);
    } else {
      if (!trade.has('grossProfit')) trade.set('grossProfit', 0);
      if (!trade.has('netProfit')) trade.set('netProfit', 0);
      if (!trade.has('totalFees')) trade.set('totalFees', 0);
      if (!trade.has('profitPercentage')) trade.set('profitPercentage', 0);
    }

    console.log(`📊 Trade beforeSave: New trade #${trade.get('tradeNumber')} status=${trade.get('status')} grossProfit=${trade.get('grossProfit')}`);
  }

  // Calculate remaining quantity
  const buyOrder = trade.get('buyOrder');
  const quantity = trade.get('quantity') || (buyOrder ? buyOrder.quantity : 0) || 0;
  const soldQuantity = trade.get('soldQuantity') || 0;
  trade.set('remainingQuantity', quantity - soldQuantity);

  // Update status based on sold quantity (only for non-iOS updates)
  if (!isNew && request.original) {
    const oldSold = request.original.get('soldQuantity') || 0;
    const newSold = trade.get('soldQuantity') || 0;

    if (newSold > oldSold) {
      if (newSold >= quantity) {
        trade.set('status', 'completed');
        trade.set('closedAt', new Date());
      } else if (newSold > 0) {
        trade.set('status', 'partial');
      }
    }

    let calculatedProfit = trade.get('calculatedProfit');

    if (calculatedProfit === undefined || calculatedProfit === null || calculatedProfit === 0) {
      const buyOrder = trade.get('buyOrder');
      const sellOrder = trade.get('sellOrder');
      const sellOrders = trade.get('sellOrders') || [];

      const buyTotal = buyOrder ? (buyOrder.totalAmount || 0) : 0;
      let sellTotal = sellOrder ? (sellOrder.totalAmount || 0) : 0;
      if (sellOrders.length > 0) {
        sellTotal = sellOrders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
      }

      if (buyTotal > 0 && sellTotal > 0) {
        calculatedProfit = sellTotal - buyTotal;
        console.log(`📊 Trade update: Calculated profit from orders: ${sellTotal} - ${buyTotal} = ${calculatedProfit}`);
      }
    }

    if (calculatedProfit !== undefined && calculatedProfit !== null && calculatedProfit !== 0) {
      trade.set('grossProfit', calculatedProfit);
      trade.set('calculatedProfit', calculatedProfit);

      const tradingFees = computeTradingFees(trade);
      trade.set('tradingFees', tradingFees);
      trade.set('totalFees', tradingFees);
      trade.set('netProfit', calculatedProfit - tradingFees);
      console.log(`📊 Trade update: grossProfit=${calculatedProfit}, tradingFees=${tradingFees}, netProfit=${calculatedProfit - tradingFees}`);
    }
  }
});

// ============================================================================
// AFTER SAVE
// ============================================================================

Parse.Cloud.afterSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !request.original;

  if (isNew) {
    await logAudit('Trade', trade.id, 'created', null, { status: 'pending' });
  }

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = trade.get('status');

    if (oldStatus !== newStatus) {
      await logAudit('Trade', trade.id, 'status_change',
        { status: oldStatus }, { status: newStatus });

      if (newStatus === 'completed') {
        try {
          const settlement = await settleAndDistribute(trade);
          if (settlement) {
            console.log(`✅ Trade #${trade.get('tradeNumber')} fully settled: commission=€${settlement.totalCommission}, investors=${settlement.investorCount}`);
          }
        } catch (err) {
          console.error(`❌ Trade #${trade.get('tradeNumber')} settlement failed:`, err.message, err.stack);
        }
      }
    }
  }
});

// ============================================================================
// HELPER: Trading fee computation (shared with beforeSave)
// ============================================================================

function computeTradingFees(trade) {
  const buyOrder = trade.get('buyOrder');
  const sellOrders = trade.get('sellOrders') || [];
  const sellOrder = trade.get('sellOrder');
  let total = 0;

  if (buyOrder) {
    total += calculateOrderFees(buyOrder.totalAmount || 0, true).totalFees;
  }

  const allSells = sellOrders.length > 0 ? sellOrders : (sellOrder ? [sellOrder] : []);
  for (const so of allSells) {
    total += calculateOrderFees(so.totalAmount || 0, true).totalFees;
  }

  return total;
}

// ============================================================================
// HELPER: Audit logging
// ============================================================================

async function logAudit(resourceType, resourceId, action, oldValues, newValues) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', action);
  log.set('resourceType', resourceType);
  log.set('resourceId', resourceId);
  if (oldValues) log.set('oldValues', oldValues);
  if (newValues) log.set('newValues', newValues);
  await log.save(null, { useMasterKey: true });
}
