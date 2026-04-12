'use strict';

const { isCriticalParameter } = require('../../utils/configHelper/index.js');

async function logConfigurationChangeRequest(request, parameterName, oldValue, newValue, reason, fourEyesRequestId) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();

  log.set('logType', 'configuration');
  log.set('action', 'configuration_change_requested');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'Configuration');
  log.set('resourceId', parameterName);
  log.set('oldValues', { [parameterName]: oldValue });
  log.set('newValues', { [parameterName]: newValue });
  log.set('metadata', {
    reason,
    fourEyesRequestId,
    isCritical: isCriticalParameter(parameterName),
    ip: request.ip,
  });

  await log.save(null, { useMasterKey: true });
}

async function logConfigurationChange(request, parameterName, oldValue, newValue, reason, fourEyesRequestId) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();

  log.set('logType', 'configuration');
  log.set('action', 'configuration_changed');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'Configuration');
  log.set('resourceId', parameterName);
  log.set('oldValues', { [parameterName]: oldValue });
  log.set('newValues', { [parameterName]: newValue });
  log.set('metadata', {
    reason,
    fourEyesRequestId,
    isCritical: isCriticalParameter(parameterName),
    appliedDirectly: !fourEyesRequestId,
    ip: request.ip,
  });

  await log.save(null, { useMasterKey: true });
}

async function logConfigurationChangeApproval(request, fourEyesReq, parameterName, oldValue, newValue) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();

  log.set('logType', 'configuration');
  log.set('action', 'configuration_change_approved');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'Configuration');
  log.set('resourceId', parameterName);
  log.set('oldValues', { [parameterName]: oldValue });
  log.set('newValues', { [parameterName]: newValue });
  log.set('metadata', {
    fourEyesRequestId: fourEyesReq.id,
    requesterId: fourEyesReq.get('requesterId'),
    requesterRole: fourEyesReq.get('requesterRole'),
    reason: fourEyesReq.get('metadata').reason,
    isCritical: true,
    ip: request.ip,
  });

  await log.save(null, { useMasterKey: true });
}

async function logConfigurationChangeRejection(request, fourEyesReq, parameterName, rejectionReason) {
  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();

  log.set('logType', 'configuration');
  log.set('action', 'configuration_change_rejected');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'Configuration');
  log.set('resourceId', parameterName);
  log.set('metadata', {
    fourEyesRequestId: fourEyesReq.id,
    requesterId: fourEyesReq.get('requesterId'),
    requesterRole: fourEyesReq.get('requesterRole'),
    originalReason: fourEyesReq.get('metadata').reason,
    rejectionReason,
    isCritical: true,
    ip: request.ip,
  });

  await log.save(null, { useMasterKey: true });
}

module.exports = {
  logConfigurationChangeRequest,
  logConfigurationChange,
  logConfigurationChangeApproval,
  logConfigurationChangeRejection,
};
