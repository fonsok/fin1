'use strict';

async function saveFourEyesAudit({
  requestId,
  action,
  requestType,
  performedBy,
  performedByRole,
  notes,
  metadata,
}) {
  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', action);
  audit.set('requestType', requestType);
  audit.set('performedBy', performedBy);
  audit.set('performedByRole', performedByRole);
  audit.set('notes', notes);
  audit.set('metadata', metadata || {});
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });
}

async function saveConfigurationAuditLog({
  action,
  userId,
  userRole,
  parameterName,
  metadata,
  oldValue,
  newValue,
}) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const configLog = new AuditLog();
  configLog.set('logType', 'configuration');
  configLog.set('action', action);
  configLog.set('userId', userId);
  configLog.set('userRole', userRole);
  configLog.set('resourceType', 'Configuration');
  configLog.set('resourceId', parameterName);
  if (oldValue !== undefined) {
    configLog.set('oldValues', { [parameterName]: oldValue });
  }
  if (newValue !== undefined) {
    configLog.set('newValues', { [parameterName]: newValue });
  }
  configLog.set('metadata', metadata || {});
  await configLog.save(null, { useMasterKey: true });
}

async function saveCorrectionAuditLog({
  userId,
  userRole,
  requestId,
  correctionType,
  targetId,
  amount,
  reason,
  applied,
  ip,
}) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const corrLog = new AuditLog();
  corrLog.set('logType', 'correction');
  corrLog.set('action', 'correction_approved');
  corrLog.set('userId', userId);
  corrLog.set('userRole', userRole);
  corrLog.set('resourceType', 'Correction');
  corrLog.set('resourceId', requestId);
  corrLog.set('metadata', {
    fourEyesRequestId: requestId,
    correctionType,
    targetId,
    amount,
    reason,
    applied,
    ip,
  });
  await corrLog.save(null, { useMasterKey: true });
}

module.exports = {
  saveFourEyesAudit,
  saveConfigurationAuditLog,
  saveCorrectionAuditLog,
};
