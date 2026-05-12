'use strict';

async function logTradeAudit(resourceType, resourceId, action, oldValues, newValues) {
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

module.exports = {
  logTradeAudit,
};
