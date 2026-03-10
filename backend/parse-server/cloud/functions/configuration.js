// ============================================================================
// Parse Cloud Code
// functions/configuration.js - Configuration Management with 4-Eyes Principle
// ============================================================================
//
// Verwaltet kritische Konfigurationsparameter mit 4-Augen-Prinzip.
//
// Workflow für kritische Parameter:
// 1. Admin beantragt Änderung → FourEyesRequest erstellt
// 2. Zweiter Admin genehmigt → Änderung wird angewendet
// 3. Alle Änderungen werden im Audit-Log protokolliert
//
// ============================================================================

'use strict';

const { logPermissionCheck } = require('../utils/permissions');
const {
  requirePermissionWithTestAuth,
  requireAdminRoleWithTestAuth,
} = require('../utils/testAuthMiddleware');
const {
  loadConfig,
  invalidateCache,
  validateConfigValue,
  isCriticalParameter,
  CRITICAL_PARAMETERS,
} = require('../utils/configHelper');

// ============================================================================
// GET CONFIGURATION
// ============================================================================

/**
 * Get current configuration.
 * Available to: admin, business_admin, compliance
 */
Parse.Cloud.define('getConfiguration', async (request) => {
  await requireAdminRoleWithTestAuth(request);

  const config = await loadConfig(true); // Force refresh

  // Log access
  await logPermissionCheck(request, 'getConfiguration', 'Configuration', config._id || 'default');

  // Flatten financial params into a single config map for the admin portal
  const flatConfig = {
    ...config.financial,
    ...config.limits,
  };

  // Ensure display is always an object with expected keys (for admin portal Configuration page)
  const display = {
    showCommissionBreakdownInCreditNote: config.display?.showCommissionBreakdownInCreditNote ?? true,
    maximumRiskExposurePercent: config.display?.maximumRiskExposurePercent ?? 2.0,
    walletFeatureEnabled: config.display?.walletFeatureEnabled ?? false,
  };

  return {
    config: flatConfig,
    financial: config.financial,
    limits: config.limits,
    display,
    metadata: {
      lastUpdated: config._updatedAt,
      updatedBy: config._updatedBy,
    },
    criticalParameters: CRITICAL_PARAMETERS,
  };
});

// ============================================================================
// REQUEST CONFIGURATION CHANGE (4-Eyes for critical params)
// ============================================================================

/**
 * Request a configuration change.
 * For critical parameters: Creates 4-eyes request requiring approval.
 * For non-critical parameters: Applies immediately.
 *
 * Available to: admin, business_admin
 */
Parse.Cloud.define('requestConfigurationChange', async (request) => {
  await requirePermissionWithTestAuth(request, 'createCorrectionRequest'); // business_admin or admin

  const { parameterName, newValue, reason } = request.params;

  if (!parameterName || newValue === undefined || !reason) {
    throw new Parse.Error(
      Parse.Error.INVALID_VALUE,
      'parameterName, newValue, and reason are required'
    );
  }

  // Validate the new value
  const validation = validateConfigValue(parameterName, newValue);
  if (!validation.valid) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, validation.error);
  }

  // Get current value
  const currentConfig = await loadConfig(true);
  const oldValue = currentConfig.financial[parameterName] ??
                   currentConfig.limits[parameterName] ??
                   currentConfig.display[parameterName];

  // Check if this is a critical parameter
  if (isCriticalParameter(parameterName)) {
    // Create 4-eyes request
    const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
    const fourEyesReq = new FourEyesRequest();

    fourEyesReq.set('requestType', 'configuration_change');
    fourEyesReq.set('requesterId', request.user.id);
    fourEyesReq.set('requesterRole', request.user.get('role'));
    fourEyesReq.set('requesterEmail', request.user.get('email'));
    fourEyesReq.set('status', 'pending');
    fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)); // 7 days
    fourEyesReq.set('metadata', {
      parameterName,
      oldValue,
      newValue,
      reason,
      isCritical: true,
    });

    await fourEyesReq.save(null, { useMasterKey: true });

    // Log the request
    await logConfigurationChangeRequest(request, parameterName, oldValue, newValue, reason, fourEyesReq.id);

    // Notify approvers
    await notifyApproversOfPendingRequest(fourEyesReq, parameterName, newValue, reason);

    return {
      success: true,
      requiresApproval: true,
      fourEyesRequestId: fourEyesReq.id,
      message: `Configuration change for '${parameterName}' requires 4-eyes approval. Request ID: ${fourEyesReq.id}`,
    };
  }

  // Non-critical parameter: Apply immediately (normalize boolean for display params)
  const valueToApply = parameterName === 'walletFeatureEnabled'
    ? Boolean(Number(newValue))
    : newValue;
  await applyConfigurationChange(parameterName, valueToApply, request.user.id);

  // Log the change
  await logConfigurationChange(request, parameterName, oldValue, newValue, reason, null);

  return {
    success: true,
    requiresApproval: false,
    message: `Configuration '${parameterName}' updated successfully.`,
  };
});

// ============================================================================
// APPROVE CONFIGURATION CHANGE
// ============================================================================

/**
 * Approve a pending configuration change request.
 * Cannot approve own request (4-eyes principle).
 *
 * Available to: admin, business_admin, compliance
 */
Parse.Cloud.define('approveConfigurationChange', async (request) => {
  await requirePermissionWithTestAuth(request, 'approveRequest');

  const { requestId, notes } = request.params;

  if (!requestId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId is required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (!req) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Request not found');
  }

  // Verify request type
  if (req.get('requestType') !== 'configuration_change') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'This is not a configuration change request');
  }

  // 4-eyes: Cannot approve own request
  if (req.get('requesterId') === request.user.id) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Cannot approve your own request (4-eyes principle)'
    );
  }

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  // Check expiry
  if (req.get('expiresAt') < new Date()) {
    req.set('status', 'expired');
    await req.save(null, { useMasterKey: true });
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request has expired');
  }

  const metadata = req.get('metadata');
  const { parameterName, newValue, oldValue, reason } = metadata;

  // Apply the configuration change
  await applyConfigurationChange(parameterName, newValue, request.user.id);

  // Update request status
  req.set('status', 'approved');
  req.set('approverId', request.user.id);
  req.set('approverRole', request.user.get('role'));
  req.set('approverEmail', request.user.get('email'));
  req.set('approverNotes', notes);
  req.set('approvedAt', new Date());
  await req.save(null, { useMasterKey: true });

  // Log the approval and change
  await logConfigurationChangeApproval(request, req, parameterName, oldValue, newValue);

  // Notify requester
  await notifyRequesterOfApproval(req, parameterName, newValue);

  return {
    success: true,
    message: `Configuration '${parameterName}' has been updated to ${formatValue(newValue)}.`,
    appliedValue: newValue,
  };
});

// ============================================================================
// REJECT CONFIGURATION CHANGE
// ============================================================================

/**
 * Reject a pending configuration change request.
 *
 * Available to: admin, business_admin, compliance
 */
Parse.Cloud.define('rejectConfigurationChange', async (request) => {
  await requirePermissionWithTestAuth(request, 'rejectRequest');

  const { requestId, reason } = request.params;

  if (!requestId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'requestId and reason are required');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const req = await new Parse.Query(FourEyesRequest).get(requestId, { useMasterKey: true });

  if (!req) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Request not found');
  }

  if (req.get('requestType') !== 'configuration_change') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'This is not a configuration change request');
  }

  if (req.get('status') !== 'pending') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Request is not pending');
  }

  const metadata = req.get('metadata');

  // Update request status
  req.set('status', 'rejected');
  req.set('approverId', request.user.id);
  req.set('approverRole', request.user.get('role'));
  req.set('rejectionReason', reason);
  req.set('rejectedAt', new Date());
  await req.save(null, { useMasterKey: true });

  // Log the rejection
  await logConfigurationChangeRejection(request, req, metadata.parameterName, reason);

  // Notify requester
  await notifyRequesterOfRejection(req, metadata.parameterName, reason);

  return {
    success: true,
    message: `Configuration change request for '${metadata.parameterName}' has been rejected.`,
  };
});

// ============================================================================
// GET PENDING CONFIGURATION CHANGES
// ============================================================================

/**
 * Get all pending configuration change requests.
 *
 * Available to: admin, business_admin, compliance
 */
Parse.Cloud.define('getPendingConfigurationChanges', async (request) => {
  await requirePermissionWithTestAuth(request, 'getPendingApprovals');

  const query = new Parse.Query('FourEyesRequest');
  query.equalTo('requestType', 'configuration_change');
  query.equalTo('status', 'pending');
  query.greaterThan('expiresAt', new Date()); // Only non-expired requests
  query.descending('createdAt');

  // Exclude own requests (4-eyes principle)
  // In development mode, allow seeing own requests for testing
  const isDevelopment = process.env.NODE_ENV !== 'production';
  if (!isDevelopment) {
    query.notEqualTo('requesterId', request.user.id);
  } else {
    console.log('🔧 Development mode: Showing all pending requests (including own)');
  }

  const requests = await query.find({ useMasterKey: true });

  return {
    requests: requests.map(r => ({
      id: r.id,
      parameterName: r.get('metadata').parameterName,
      oldValue: r.get('metadata').oldValue,
      newValue: r.get('metadata').newValue,
      reason: r.get('metadata').reason,
      requesterId: r.get('requesterId'),
      requesterEmail: r.get('requesterEmail'),
      requesterRole: r.get('requesterRole'),
      createdAt: r.get('createdAt'),
      expiresAt: r.get('expiresAt'),
    })),
    total: requests.length,
  };
});

// ============================================================================
// GET CONFIGURATION CHANGE HISTORY
// ============================================================================

/**
 * Get configuration change history (audit trail).
 *
 * Available to: admin, compliance
 */
Parse.Cloud.define('getConfigurationChangeHistory', async (request) => {
  await requirePermissionWithTestAuth(request, 'getAuditLogs');

  const { limit = 50, skip = 0 } = request.params;

  const query = new Parse.Query('AuditLog');
  query.equalTo('resourceType', 'Configuration');
  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const logs = await query.find({ useMasterKey: true });
  const total = await query.count({ useMasterKey: true });

  return {
    logs: logs.map(l => l.toJSON()),
    total,
  };
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Apply a configuration change to the database.
 */
async function applyConfigurationChange(parameterName, newValue, userId) {
  const Configuration = Parse.Object.extend('Configuration');
  const query = new Parse.Query(Configuration);
  query.equalTo('isActive', true);

  let config = await query.first({ useMasterKey: true });

  if (!config) {
    config = new Configuration();
    config.set('isActive', true);
  }

  // Set the new value
  config.set(parameterName, newValue);
  config.set('updatedBy', userId);
  config.set('updatedAt', new Date());

  await config.save(null, { useMasterKey: true });

  // Invalidate cache
  invalidateCache();

  console.log(`✅ Configuration '${parameterName}' updated to ${newValue} by ${userId}`);
}

/**
 * Log a configuration change request.
 */
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

/**
 * Log a configuration change (applied).
 */
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

/**
 * Log a configuration change approval.
 */
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

/**
 * Log a configuration change rejection.
 */
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

/**
 * Notify approvers of a pending configuration change request.
 */
async function notifyApproversOfPendingRequest(fourEyesReq, parameterName, newValue, reason) {
  // Find all users with approval roles (except requester)
  const approvalRoles = ['admin', 'business_admin', 'compliance'];
  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('role', approvalRoles);
  userQuery.notEqualTo('objectId', fourEyesReq.get('requesterId'));
  userQuery.equalTo('status', 'active');

  const approvers = await userQuery.find({ useMasterKey: true });

  for (const approver of approvers) {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', approver.id);
    notif.set('type', 'configuration_change_pending');
    notif.set('category', 'admin');
    notif.set('title', 'Konfigurationsänderung erfordert Genehmigung');
    notif.set('message', `Eine Änderung von '${parameterName}' auf ${formatValue(newValue)} wurde beantragt. Grund: ${reason}`);
    notif.set('priority', 'high');
    notif.set('isRead', false);
    notif.set('channels', ['in_app', 'push']);
    notif.set('metadata', { fourEyesRequestId: fourEyesReq.id });
    await notif.save(null, { useMasterKey: true });
  }
}

/**
 * Notify requester that their request was approved.
 */
async function notifyRequesterOfApproval(fourEyesReq, parameterName, newValue) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', fourEyesReq.get('requesterId'));
  notif.set('type', 'configuration_change_approved');
  notif.set('category', 'admin');
  notif.set('title', 'Konfigurationsänderung genehmigt');
  notif.set('message', `Ihre Änderung von '${parameterName}' auf ${formatValue(newValue)} wurde genehmigt und angewendet.`);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

/**
 * Notify requester that their request was rejected.
 */
async function notifyRequesterOfRejection(fourEyesReq, parameterName, reason) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', fourEyesReq.get('requesterId'));
  notif.set('type', 'configuration_change_rejected');
  notif.set('category', 'admin');
  notif.set('title', 'Konfigurationsänderung abgelehnt');
  notif.set('message', `Ihre Änderung von '${parameterName}' wurde abgelehnt. Grund: ${reason}`);
  notif.set('priority', 'high');
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

/**
 * Format a value for display.
 */
function formatValue(value) {
  if (typeof value === 'number') {
    if (value < 1) {
      return `${(value * 100).toFixed(1)}%`;
    }
    return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(value);
  }
  return String(value);
}
