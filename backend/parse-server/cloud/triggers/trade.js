// ============================================================================
// Parse Cloud Code
// triggers/trade.js - Trade Triggers
// ============================================================================

'use strict';

const { getTraderCommissionRate } = require('../utils/configHelper');

// ============================================================================
// BEFORE SAVE
// ============================================================================

Parse.Cloud.beforeSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !trade.existed();

  if (isNew) {
    // Generate trade number only if not provided by iOS app
    if (!trade.get('tradeNumber')) {
      const lastTrade = await new Parse.Query('Trade')
        .descending('tradeNumber')
        .first({ useMasterKey: true });

      const nextNumber = lastTrade ? (lastTrade.get('tradeNumber') || 0) + 1 : 1;
      trade.set('tradeNumber', nextNumber);
    }

    // Set defaults ONLY if not already set by iOS app
    // iOS sends: status, buyOrder, sellOrder, calculatedProfit
    if (!trade.get('status')) {
      trade.set('status', 'pending');
    }

    // Get quantity from buyOrder if not set directly (iOS format)
    const buyOrder = trade.get('buyOrder');
    const directQuantity = trade.get('quantity');
    const quantity = directQuantity || (buyOrder ? buyOrder.quantity : 0);

    if (!trade.has('soldQuantity')) trade.set('soldQuantity', 0);
    if (!trade.has('remainingQuantity')) trade.set('remainingQuantity', quantity);

    // Map iOS calculatedProfit to backend grossProfit if provided
    const calculatedProfit = trade.get('calculatedProfit');
    if (calculatedProfit !== undefined && calculatedProfit !== null) {
      trade.set('grossProfit', calculatedProfit);
      // Calculate commission at 10%
      const commission = calculatedProfit > 0 ? calculatedProfit * 0.10 : 0;
      trade.set('totalFees', commission);
      trade.set('netProfit', calculatedProfit - commission);
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

    // Update from iOS calculatedProfit OR calculate from orders
    let calculatedProfit = trade.get('calculatedProfit');

    // If no calculatedProfit, calculate from buyOrder and sellOrders
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
      const commission = calculatedProfit > 0 ? calculatedProfit * 0.10 : 0;
      trade.set('totalFees', commission);
      trade.set('netProfit', calculatedProfit - commission);
      console.log(`📊 Trade update: Set grossProfit=${calculatedProfit}, commission=${commission}`);
    }
  }
});

// ============================================================================
// AFTER SAVE
// ============================================================================

Parse.Cloud.afterSave('Trade', async (request) => {
  const trade = request.object;
  const isNew = !request.original;
  const traderId = trade.get('traderId');

  if (isNew) {
    // Log trade creation
    await logAudit('Trade', trade.id, 'created', null, { status: 'pending' });
  }

  // Status change handling
  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = trade.get('status');

    if (oldStatus !== newStatus) {
      await logAudit('Trade', trade.id, 'status_change',
        { status: oldStatus }, { status: newStatus });

      // Trade completed - distribute profits to investors
      if (newStatus === 'completed') {
        await distributeTradeProfit(trade);
      }
    }
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

async function distributeTradeProfit(trade) {
  const traderId = trade.get('traderId');
  const grossProfit = trade.get('grossProfit') || 0;

  if (grossProfit <= 0) return;

  // Load commission rate from Configuration (admin-configured value)
  // This ensures consistency between App UI and Backend calculations
  const commissionRate = await getTraderCommissionRate();
  console.log(`📊 [Trade ${trade.id}] Using commission rate: ${(commissionRate * 100).toFixed(1)}% (from Configuration)`);

  // Find all pool participations for this trade
  const PoolParticipation = Parse.Object.extend('PoolTradeParticipation');
  const query = new Parse.Query(PoolParticipation);
  query.equalTo('tradeId', trade.id);
  query.equalTo('isSettled', false);

  const participations = await query.find({ useMasterKey: true });

  for (const participation of participations) {
    const ownershipPct = participation.get('ownershipPercentage') || 0;
    const profitShare = grossProfit * (ownershipPct / 100);
    const commission = profitShare * commissionRate;
    const netProfit = profitShare - commission;

    participation.set('profitShare', profitShare);
    participation.set('commissionAmount', commission);
    participation.set('commissionRate', commissionRate);
    participation.set('grossReturn', netProfit);
    participation.set('isSettled', true);
    participation.set('settledAt', new Date());

    await participation.save(null, { useMasterKey: true });

    // Update investment
    const investmentId = participation.get('investmentId');
    const Investment = Parse.Object.extend('Investment');
    const investment = await new Parse.Query(Investment).get(investmentId, { useMasterKey: true });

    if (investment) {
      const currentValue = (investment.get('currentValue') || 0) + netProfit;
      const totalProfit = (investment.get('profit') || 0) + netProfit;
      const totalCommission = (investment.get('totalCommissionPaid') || 0) + commission;
      const numTrades = (investment.get('numberOfTrades') || 0) + 1;

      investment.set('currentValue', currentValue);
      investment.set('profit', totalProfit);
      investment.set('totalCommissionPaid', totalCommission);
      investment.set('numberOfTrades', numTrades);

      // Calculate profit percentage
      const initialValue = investment.get('initialValue') || investment.get('amount');
      if (initialValue > 0) {
        investment.set('profitPercentage', (totalProfit / initialValue) * 100);
      }

      await investment.save(null, { useMasterKey: true });

      // Notify investor
      const investorId = investment.get('investorId');
      await createNotification(investorId, 'investment_profit', 'investment',
        'Gewinn erzielt',
        `Ihr Investment hat einen Gewinn von ${formatCurrency(netProfit)} erzielt.`);
    }

    // Create commission record
    await createCommission(traderId, investment, trade, participation, commission);
  }
}

async function createCommission(traderId, investment, trade, participation, amount) {
  const Commission = Parse.Object.extend('Commission');
  const commission = new Commission();

  // Generate commission number
  const lastComm = await new Parse.Query('Commission')
    .startsWith('commissionNumber', `COM-${new Date().getFullYear()}-`)
    .descending('commissionNumber')
    .first({ useMasterKey: true });

  let seq = 1;
  if (lastComm) {
    const parts = lastComm.get('commissionNumber').split('-');
    seq = parseInt(parts[2], 10) + 1;
  }

  commission.set('commissionNumber', `COM-${new Date().getFullYear()}-${seq.toString().padStart(7, '0')}`);
  commission.set('traderId', traderId);
  commission.set('investorId', investment.get('investorId'));
  commission.set('investmentId', investment.id);
  commission.set('tradeId', trade.id);
  commission.set('participationId', participation.id);
  commission.set('investorGrossProfit', participation.get('profitShare'));
  commission.set('commissionRate', participation.get('commissionRate'));
  commission.set('commissionAmount', amount);
  commission.set('status', 'pending');

  await commission.save(null, { useMasterKey: true });
}

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

async function createNotification(userId, type, category, title, message) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}
