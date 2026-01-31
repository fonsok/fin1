// ============================================================================
// FIN1 Parse Cloud Code
// triggers/investment.js - Investment Triggers
// ============================================================================

'use strict';

const { generateSequentialNumber, calculateServiceCharge } = require('../utils/helpers');

// ============================================================================
// BEFORE SAVE
// ============================================================================

Parse.Cloud.beforeSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !investment.existed();

  // ========== NEW INVESTMENT ==========
  if (isNew) {
    // Generate investment number
    if (!investment.get('investmentNumber')) {
      const investmentNumber = await generateSequentialNumber('INV', 'Investment', 'investmentNumber');
      investment.set('investmentNumber', investmentNumber);
    }

    // Validate amount
    const amount = investment.get('amount');
    if (!amount || amount < 100) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE,
        'Investment amount must be at least €100');
    }

    // Validate investor != trader
    const investorId = investment.get('investorId');
    const traderId = investment.get('traderId');
    if (investorId === traderId) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE,
        'Investor cannot invest in their own pool');
    }

    // Calculate service charge
    const serviceChargeRate = investment.get('serviceChargeRate') || 0.015;
    const serviceCharge = calculateServiceCharge(amount, serviceChargeRate);

    investment.set('serviceChargeRate', serviceCharge.rate);
    investment.set('serviceChargeAmount', serviceCharge.serviceCharge);
    investment.set('serviceChargeVat', serviceCharge.vat);
    investment.set('initialValue', serviceCharge.netAmount);
    investment.set('currentValue', serviceCharge.netAmount);

    // Set defaults
    investment.set('status', 'reserved');
    investment.set('profit', 0);
    investment.set('profitPercentage', 0);
    investment.set('totalCommissionPaid', 0);
    investment.set('numberOfTrades', 0);
    investment.set('reservedAt', new Date());

    // Set reservation expiry (24 hours)
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);
    investment.set('reservationExpiresAt', expiresAt);

    // Get trader info for snapshot
    const traderQuery = new Parse.Query(Parse.User);
    const trader = await traderQuery.get(traderId, { useMasterKey: true });
    if (trader) {
      const profileQuery = new Parse.Query('UserProfile');
      profileQuery.equalTo('userId', traderId);
      const profile = await profileQuery.first({ useMasterKey: true });

      if (profile) {
        investment.set('traderName', `${profile.get('firstName')} ${profile.get('lastName').charAt(0)}.`);
      }
    }
  }

  // ========== STATUS CHANGE VALIDATION ==========
  if (!isNew && request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = investment.get('status');

    // Valid status transitions
    const validTransitions = {
      'reserved': ['active', 'cancelled'],
      'active': ['executing', 'paused', 'closing', 'cancelled'],
      'executing': ['active', 'paused'],
      'paused': ['active', 'closing', 'cancelled'],
      'closing': ['completed'],
      'completed': [],
      'cancelled': []
    };

    if (oldStatus !== newStatus) {
      const allowed = validTransitions[oldStatus] || [];
      if (!allowed.includes(newStatus)) {
        throw new Parse.Error(Parse.Error.INVALID_VALUE,
          `Invalid status transition from ${oldStatus} to ${newStatus}`);
      }

      // Set timestamp
      if (newStatus === 'active') {
        investment.set('activatedAt', new Date());
      } else if (newStatus === 'completed') {
        investment.set('completedAt', new Date());
      } else if (newStatus === 'cancelled') {
        investment.set('cancelledAt', new Date());
      }
    }
  }
});

// ============================================================================
// AFTER SAVE
// ============================================================================

Parse.Cloud.afterSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !request.original;

  const investorId = investment.get('investorId');
  const traderId = investment.get('traderId');
  const amount = investment.get('amount');

  // ========== NEW INVESTMENT ==========
  if (isNew) {
    // Notify investor
    await createNotification(investorId, 'investment_created', 'investment',
      'Investment erstellt',
      `Ihr Investment über ${formatCurrency(amount)} wurde erstellt. ` +
      `Bitte bestätigen Sie innerhalb von 24 Stunden.`);

    // Notify trader
    await createNotification(traderId, 'investment_created', 'investment',
      'Neues Investment',
      `Ein neuer Investor hat ${formatCurrency(amount)} in Ihren Pool investiert.`);

    // Log compliance event
    await logComplianceEvent(investorId, 'order_placed', 'info',
      `Investment created: ${investment.get('investmentNumber')}`,
      { amount, traderId });
  }

  // ========== STATUS CHANGE ==========
  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = investment.get('status');

    if (oldStatus !== newStatus) {
      // Log audit
      await logInvestmentAudit(investment.id,
        newStatus === 'active' ? 'activated' :
        newStatus === 'completed' ? 'completed' :
        newStatus === 'cancelled' ? 'cancelled' : 'status_change',
        oldStatus, newStatus);

      // Notify investor
      if (newStatus === 'active') {
        await createNotification(investorId, 'investment_activated', 'investment',
          'Investment aktiviert',
          `Ihr Investment ${investment.get('investmentNumber')} ist jetzt aktiv.`);

        // Deduct from wallet
        await processWalletTransaction(investorId, 'investment', -amount,
          `Investment ${investment.get('investmentNumber')}`,
          'investment', investment.id);

      } else if (newStatus === 'completed') {
        const profit = investment.get('profit') || 0;
        const finalValue = investment.get('currentValue');

        await createNotification(investorId, 'investment_completed', 'investment',
          'Investment abgeschlossen',
          `Ihr Investment wurde abgeschlossen. Gewinn: ${formatCurrency(profit)}`);

        // Credit to wallet
        await processWalletTransaction(investorId, 'investment_return', finalValue,
          `Investment Rückzahlung ${investment.get('investmentNumber')}`,
          'investment', investment.id);

      } else if (newStatus === 'cancelled') {
        // Refund if was active
        if (oldStatus === 'active') {
          const refundAmount = investment.get('currentValue');
          await processWalletTransaction(investorId, 'refund', refundAmount,
            `Investment Stornierung ${investment.get('investmentNumber')}`,
            'investment', investment.id);
        }

        await createNotification(investorId, 'investment_cancelled', 'investment',
          'Investment storniert',
          `Ihr Investment ${investment.get('investmentNumber')} wurde storniert.`,
          'high');
      }
    }
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR'
  }).format(amount);
}

async function createNotification(userId, type, category, title, message, priority = 'normal') {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', userId);
  notif.set('type', type);
  notif.set('category', category);
  notif.set('title', title);
  notif.set('message', message);
  notif.set('priority', priority);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

async function logComplianceEvent(userId, eventType, severity, description, metadata = {}) {
  const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
  const event = new ComplianceEvent();
  event.set('userId', userId);
  event.set('eventType', eventType);
  event.set('severity', severity);
  event.set('description', description);
  event.set('metadata', metadata);
  event.set('occurredAt', new Date());
  await event.save(null, { useMasterKey: true });
}

async function logInvestmentAudit(investmentId, action, oldStatus, newStatus) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', action);
  log.set('resourceType', 'Investment');
  log.set('resourceId', investmentId);
  log.set('oldValues', { status: oldStatus });
  log.set('newValues', { status: newStatus });
  await log.save(null, { useMasterKey: true });
}

async function processWalletTransaction(userId, type, amount, description, refType, refId) {
  // This would call the wallet function
  const WalletTransaction = Parse.Object.extend('WalletTransaction');
  const tx = new WalletTransaction();
  tx.set('userId', userId);
  tx.set('transactionType', type);
  tx.set('amount', amount);
  tx.set('description', description);
  tx.set('referenceType', refType);
  tx.set('referenceId', refId);
  tx.set('status', 'completed');
  tx.set('completedAt', new Date());
  await tx.save(null, { useMasterKey: true });
}
