// ============================================================================
// FIN1 Parse Cloud Code
// triggers/wallet.js - Wallet Transaction Triggers
// ============================================================================

'use strict';

const { generateSequentialNumber } = require('../utils/helpers');

Parse.Cloud.beforeSave('WalletTransaction', async (request) => {
  const tx = request.object;
  const isNew = !tx.existed();

  if (isNew) {
    // Generate transaction number
    if (!tx.get('transactionNumber')) {
      const txNumber = await generateSequentialNumber('TXN', 'WalletTransaction', 'transactionNumber');
      tx.set('transactionNumber', txNumber);
    }

    // Set defaults
    tx.set('status', tx.get('status') || 'pending');
    tx.set('transactionDate', tx.get('transactionDate') || new Date());

    // Calculate balance
    const userId = tx.get('userId');
    const amount = tx.get('amount');
    const type = tx.get('transactionType');

    // Get current balance
    const lastTx = await new Parse.Query('WalletTransaction')
      .equalTo('userId', userId)
      .equalTo('status', 'completed')
      .descending('completedAt')
      .first({ useMasterKey: true });

    const balanceBefore = lastTx ? (lastTx.get('balanceAfter') || 0) : 0;
    tx.set('balanceBefore', balanceBefore);

    // Calculate new balance
    const creditTypes = ['deposit', 'trade_sell', 'profit_distribution', 'commission_credit', 'refund', 'investment_return'];
    const isCredit = creditTypes.includes(type);
    const balanceAfter = isCredit ? balanceBefore + Math.abs(amount) : balanceBefore - Math.abs(amount);

    tx.set('balanceAfter', balanceAfter);

    // Validate sufficient balance for debits
    if (!isCredit && balanceAfter < 0) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Insufficient balance');
    }
  }
});

Parse.Cloud.afterSave('WalletTransaction', async (request) => {
  const tx = request.object;

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = tx.get('status');

    if (oldStatus !== newStatus && newStatus === 'completed') {
      tx.set('completedAt', new Date());

      const type = tx.get('transactionType');
      const amount = tx.get('amount');
      const userId = tx.get('userId');

      // Large transaction compliance check
      if (Math.abs(amount) >= 10000 && ['deposit', 'withdrawal'].includes(type)) {
        const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
        const event = new ComplianceEvent();
        event.set('userId', userId);
        event.set('eventType', 'large_transaction');
        event.set('severity', Math.abs(amount) >= 15000 ? 'high' : 'medium');
        event.set('description', `Large ${type} of ${amount}€`);
        event.set('metadata', { transactionId: tx.id, amount, type });
        event.set('regulatoryFlags', ['gwg', 'aml']);
        event.set('requiresReview', Math.abs(amount) >= 15000);
        event.set('occurredAt', new Date());
        await event.save(null, { useMasterKey: true });
      }

      // Notify user
      if (['deposit', 'withdrawal'].includes(type)) {
        const Notification = Parse.Object.extend('Notification');
        const notif = new Notification();
        notif.set('userId', userId);
        notif.set('type', type === 'deposit' ? 'deposit_received' : 'withdrawal_completed');
        notif.set('category', 'wallet');
        notif.set('title', type === 'deposit' ? 'Einzahlung erhalten' : 'Auszahlung abgeschlossen');
        notif.set('message', `${Math.abs(amount).toFixed(2)} € wurden ${type === 'deposit' ? 'eingezahlt' : 'ausgezahlt'}.`);
        notif.set('isRead', false);
        await notif.save(null, { useMasterKey: true });
      }
    }
  }
});
