'use strict';

function formatCurrency(amount) {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
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

module.exports = {
  formatCurrency,
  createNotification,
  logComplianceEvent,
  logInvestmentAudit,
  processWalletTransaction,
};
