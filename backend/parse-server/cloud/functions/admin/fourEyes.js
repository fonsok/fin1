'use strict';

const { requirePermission, logPermissionCheck } = require('../../utils/permissions');
const { getRequesterIdString } = require('./helpers');
const { getTraderCommissionRate, invalidateCache, validateConfigValue } = require('../../utils/configHelper');

Parse.Cloud.define('getPendingApprovals', async (request) => {
  requirePermission(request, 'getPendingApprovals');

  const userIdStr = String(request.user.id);

  const pendingQuery = new Parse.Query('FourEyesRequest');
  pendingQuery.equalTo('status', 'pending');
  pendingQuery.greaterThan('expiresAt', new Date());
  pendingQuery.descending('createdAt');
  const allPending = await pendingQuery.find({ useMasterKey: true });

  const pendingOthers = [];
  const ownPending = [];
  for (const r of allPending) {
    const rid = getRequesterIdString(r);
    if (rid === userIdStr) {
      ownPending.push(r);
    } else {
      pendingOthers.push(r);
    }
  }

  const historyQuery = new Parse.Query('FourEyesRequest');
  historyQuery.containedIn('status', ['approved', 'rejected', 'expired', 'withdrawn']);
  historyQuery.greaterThan('updatedAt', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
  historyQuery.descending('updatedAt');
  historyQuery.limit(50);
  const history = await historyQuery.find({ useMasterKey: true });

  const allQuery = new Parse.Query('FourEyesRequest');
  allQuery.descending('createdAt');
  allQuery.limit(100);
  const allRequests = await allQuery.find({ useMasterKey: true });

  function toApprovalJson(obj) {
    const json = obj.toJSON ? obj.toJSON() : obj;
    if (json.requesterId != null && typeof json.requesterId !== 'string') {
      json.requesterId = json.requesterId.objectId || json.requesterId.id || String(json.requesterId);
    }
    return json;
  }

  return {
    requests: pendingOthers.map(toApprovalJson),
    ownPending: ownPending.map(toApprovalJson),
    history: history.map(toApprovalJson),
    allRequests: allRequests.map(toApprovalJson),
  };
});

Parse.Cloud.define('withdrawRequest', async (request) => {
  requirePermission(request, 'getPendingApprovals');

  const { requestId, reason } = request.params;

  if (!requestId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (req.get('requesterId') !== request.user.id) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Only the original requester can withdraw this request'
    );
  }

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Only pending requests can be withdrawn');
  }

  req.set('status', 'withdrawn');
  req.set('withdrawnAt', new Date());
  req.set('withdrawnReason', reason || 'Vom Antragsteller zurückgezogen');
  await req.save(null, { useMasterKey: true });

  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', 'withdrawn');
  audit.set('requestType', req.get('requestType'));
  audit.set('performedBy', request.user.id);
  audit.set('performedByRole', request.user.get('role'));
  audit.set('notes', reason || 'Vom Antragsteller zurückgezogen');
  audit.set('metadata', req.get('metadata'));
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });

  return { success: true, message: 'Antrag zurückgezogen.' };
});

Parse.Cloud.define('approveRequest', async (request) => {
  requirePermission(request, 'approveRequest');

  const { requestId, notes } = request.params;

  if (!requestId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (req.get('requesterId') === request.user.id) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Cannot approve own request (4-eyes principle)'
    );
  }

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  if (req.get('expiresAt') < new Date()) {
    req.set('status', 'expired');
    await req.save(null, { useMasterKey: true });
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request has expired');
  }

  const requestType = req.get('requestType');
  const metadata = req.get('metadata') || {};

  if (requestType === 'configuration_change') {
    const { parameterName, newValue, oldValue } = metadata;

    const validation = validateConfigValue(parameterName, newValue);
    if (!validation.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, `Value no longer valid: ${validation.error}`);
    }

    const Configuration = Parse.Object.extend('Configuration');
    const configQuery = new Parse.Query(Configuration);
    configQuery.equalTo('isActive', true);
    let config = await configQuery.first({ useMasterKey: true });
    if (!config) {
      config = new Configuration();
      config.set('isActive', true);
    }
    config.set(parameterName, newValue);
    config.set('updatedBy', request.user.id);
    config.set('updatedAt', new Date());
    await config.save(null, { useMasterKey: true });
    invalidateCache();

    const AuditLog = Parse.Object.extend('AuditLog');
    const configLog = new AuditLog();
    configLog.set('logType', 'configuration');
    configLog.set('action', 'configuration_change_approved');
    configLog.set('userId', request.user.id);
    configLog.set('userRole', request.user.get('role'));
    configLog.set('resourceType', 'Configuration');
    configLog.set('resourceId', parameterName);
    configLog.set('oldValues', { [parameterName]: oldValue });
    configLog.set('newValues', { [parameterName]: newValue });
    configLog.set('metadata', {
      fourEyesRequestId: requestId,
      requesterId: req.get('requesterId'),
      reason: metadata.reason,
      isCritical: true,
      ip: request.ip,
    });
    await configLog.save(null, { useMasterKey: true });

    console.log(`✅ Configuration '${parameterName}' updated to ${newValue} via 4-eyes approval by ${request.user.id}`);
  }

  req.set('status', 'approved');
  req.set('approverId', request.user.id);
  req.set('approverRole', request.user.get('role'));
  req.set('approverEmail', request.user.get('email'));
  req.set('approverNotes', notes);
  req.set('approvedAt', new Date());
  await req.save(null, { useMasterKey: true });

  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', 'approved');
  audit.set('requestType', requestType);
  audit.set('performedBy', request.user.id);
  audit.set('performedByRole', request.user.get('role'));
  audit.set('notes', notes);
  audit.set('metadata', metadata);
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });

  try {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', req.get('requesterId'));
    notif.set('type', `${requestType}_approved`);
    notif.set('category', 'admin');
    notif.set('title', 'Anfrage genehmigt');
    notif.set('message', requestType === 'configuration_change'
      ? `Ihre Konfigurationsänderung '${metadata.parameterName}' wurde genehmigt und angewendet.`
      : `Ihre Anfrage (${requestType}) wurde genehmigt.`);
    notif.set('isRead', false);
    notif.set('channels', ['in_app', 'push']);
    await notif.save(null, { useMasterKey: true });
  } catch (err) {
    console.error('Failed to send approval notification:', err.message);
  }

  return {
    success: true,
    requestType,
    applied: requestType === 'configuration_change',
    message: requestType === 'configuration_change'
      ? `Konfiguration '${metadata.parameterName}' wurde auf ${metadata.newValue} gesetzt.`
      : 'Anfrage genehmigt.',
  };
});

Parse.Cloud.define('rejectRequest', async (request) => {
  requirePermission(request, 'rejectRequest');

  const { requestId, reason } = request.params;

  if (!requestId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId and reason required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  const requestType = req.get('requestType');
  const metadata = req.get('metadata') || {};

  req.set('status', 'rejected');
  req.set('approverId', request.user.id);
  req.set('approverRole', request.user.get('role'));
  req.set('approverEmail', request.user.get('email'));
  req.set('rejectionReason', reason);
  req.set('rejectedAt', new Date());

  await req.save(null, { useMasterKey: true });

  const FourEyesAudit = Parse.Object.extend('FourEyesAudit');
  const audit = new FourEyesAudit();
  audit.set('requestId', requestId);
  audit.set('action', 'rejected');
  audit.set('requestType', requestType);
  audit.set('performedBy', request.user.id);
  audit.set('performedByRole', request.user.get('role'));
  audit.set('notes', reason);
  audit.set('metadata', metadata);
  audit.set('performedAt', new Date());
  await audit.save(null, { useMasterKey: true });

  if (requestType === 'configuration_change') {
    const AuditLog = Parse.Object.extend('AuditLog');
    const configLog = new AuditLog();
    configLog.set('logType', 'configuration');
    configLog.set('action', 'configuration_change_rejected');
    configLog.set('userId', request.user.id);
    configLog.set('userRole', request.user.get('role'));
    configLog.set('resourceType', 'Configuration');
    configLog.set('resourceId', metadata.parameterName);
    configLog.set('metadata', {
      fourEyesRequestId: requestId,
      requesterId: req.get('requesterId'),
      originalReason: metadata.reason,
      rejectionReason: reason,
      isCritical: true,
      ip: request.ip,
    });
    await configLog.save(null, { useMasterKey: true });
  }

  try {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', req.get('requesterId'));
    notif.set('type', `${requestType}_rejected`);
    notif.set('category', 'admin');
    notif.set('title', 'Anfrage abgelehnt');
    notif.set('message', requestType === 'configuration_change'
      ? `Ihre Konfigurationsänderung '${metadata.parameterName}' wurde abgelehnt. Grund: ${reason}`
      : `Ihre Anfrage (${requestType}) wurde abgelehnt. Grund: ${reason}`);
    notif.set('priority', 'high');
    notif.set('isRead', false);
    notif.set('channels', ['in_app', 'push']);
    await notif.save(null, { useMasterKey: true });
  } catch (err) {
    console.error('Failed to send rejection notification:', err.message);
  }

  return { success: true };
});
