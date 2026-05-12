'use strict';

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
  notif.set('channels', ['in_app']);
  await notif.save(null, { useMasterKey: true });
}

module.exports = {
  logComplianceEvent,
  createNotification,
};
