// ============================================================================
// Parse Cloud Code
// functions/security.js - Security Dashboard Functions
// ============================================================================
//
// Erweiterte Security-Funktionen für das Admin Portal.
// Ergänzt die Basis-Funktionen in admin.js
//
// ============================================================================

'use strict';

const { requirePermission, logPermissionCheck } = require('../utils/permissions');
const { applyQuerySort } = require('../utils/applyQuerySort');

// ============================================================================
// SECURITY DASHBOARD STATS (Extended)
// ============================================================================

/**
 * Get security dashboard stats in frontend-expected format.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('getSecurityDashboardStats', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  // Failed logins today
  const failedTodayQuery = new Parse.Query('AuditLog');
  failedTodayQuery.equalTo('action', 'login_failed');
  failedTodayQuery.greaterThanOrEqualTo('createdAt', todayStart);
  const failedLoginsToday = await failedTodayQuery.count({ useMasterKey: true });

  // Failed logins this week
  const failedWeekQuery = new Parse.Query('AuditLog');
  failedWeekQuery.equalTo('action', 'login_failed');
  failedWeekQuery.greaterThanOrEqualTo('createdAt', weekStart);
  const failedLoginsWeek = await failedWeekQuery.count({ useMasterKey: true });

  // Locked accounts
  const lockedQuery = new Parse.Query(Parse.User);
  lockedQuery.equalTo('status', 'locked');
  const lockedAccounts = await lockedQuery.count({ useMasterKey: true });

  // Active sessions (approximate via Session class)
  const sessionQuery = new Parse.Query(Parse.Session);
  sessionQuery.greaterThanOrEqualTo('createdAt', weekStart);
  const activeSessions = await sessionQuery.count({ useMasterKey: true });

  // Suspicious activities (unreviewed compliance events)
  const suspiciousQuery = new Parse.Query('ComplianceEvent');
  suspiciousQuery.containedIn('eventType', [
    'suspicious_activity',
    'login_from_new_device',
    'failed_login_attempt',
    'aml_check_failed'
  ]);
  suspiciousQuery.equalTo('reviewed', false);
  const suspiciousActivities = await suspiciousQuery.count({ useMasterKey: true });

  return {
    stats: {
      failedLoginsToday,
      failedLoginsWeek,
      lockedAccounts,
      activeSessions,
      suspiciousActivities,
    }
  };
});

// ============================================================================
// FAILED LOGIN ATTEMPTS
// ============================================================================

/**
 * Get failed login attempts.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('getFailedLoginAttempts', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const { limit = 50, skip = 0 } = request.params;

  function buildFailedLoginQuery() {
    const q = new Parse.Query('AuditLog');
    q.equalTo('action', 'login_failed');
    return q;
  }

  const countQuery = buildFailedLoginQuery();
  const total = await countQuery.count({ useMasterKey: true });

  const pageQuery = buildFailedLoginQuery();
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['createdAt', 'updatedAt', 'resourceId'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(limit);

  const logs = await pageQuery.find({ useMasterKey: true });

  const logins = logs.map(log => ({
    objectId: log.id,
    email: log.get('metadata')?.email || log.get('resourceId') || 'Unknown',
    ipAddress: log.get('metadata')?.ipAddress || log.get('metadata')?.ip || '-',
    userAgent: log.get('metadata')?.userAgent || '-',
    timestamp: log.get('createdAt')?.toISOString(),
    reason: log.get('metadata')?.reason || 'Invalid credentials',
  }));

  return { logins, total };
});

// ============================================================================
// ACTIVE SESSIONS
// ============================================================================

/**
 * Get active sessions.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('getActiveSessions', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const { limit = 100, skip = 0 } = request.params;

  const countQuery = new Parse.Query(Parse.Session);
  const pageQuery = new Parse.Query(Parse.Session);
  pageQuery.include('user');
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['createdAt', 'updatedAt', 'expiresAt'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(limit);

  const [sessionObjects, total] = await Promise.all([
    pageQuery.find({ useMasterKey: true }),
    countQuery.count({ useMasterKey: true }),
  ]);

  const sessions = [];
  for (const session of sessionObjects) {
    const user = session.get('user');
    if (user) {
      sessions.push({
        objectId: session.id,
        userId: user.id,
        email: user.get('email') || 'Unknown',
        ipAddress: session.get('installationId') || '-',
        device: session.get('createdWith')?.action || 'Unknown',
        createdAt: session.get('createdAt')?.toISOString(),
        lastActivity: session.get('updatedAt')?.toISOString() || session.get('createdAt')?.toISOString(),
      });
    }
  }

  return { sessions, total };
});

// ============================================================================
// SECURITY ALERTS
// ============================================================================

/**
 * Get security alerts (compliance events that are security-related).
 * Available to: admin, security_officer
 */
Parse.Cloud.define('getSecurityAlerts', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const { limit = 50, skip = 0, reviewed } = request.params;

  const EVENT_TYPES = [
    'suspicious_activity',
    'login_from_new_device',
    'failed_login_attempt',
    'aml_check_failed',
    'account_locked',
    'password_changed',
    'two_factor_disabled',
  ];

  function buildAlertsQuery() {
    const q = new Parse.Query('ComplianceEvent');
    q.containedIn('eventType', EVENT_TYPES);
    if (reviewed !== undefined) {
      q.equalTo('reviewed', reviewed);
    }
    return q;
  }

  const countQuery = buildAlertsQuery();
  const total = await countQuery.count({ useMasterKey: true });

  const pageQuery = buildAlertsQuery();
  applyQuerySort(pageQuery, request.params || {}, {
    allowed: ['occurredAt', 'createdAt', 'severity', 'eventType', 'reviewed'],
    defaultField: 'occurredAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(limit);

  const events = await pageQuery.find({ useMasterKey: true });

  const alerts = await Promise.all(events.map(async (event) => {
    let email = null;
    const userId = event.get('userId');

    // Try to get user email
    if (userId) {
      try {
        const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
        email = user.get('email');
      } catch {
        // User might not exist
      }
    }

    return {
      objectId: event.id,
      type: event.get('eventType'),
      severity: event.get('severity') || 'medium',
      message: event.get('description') || `Security event: ${event.get('eventType')}`,
      userId: userId,
      email: email,
      createdAt: event.get('occurredAt')?.toISOString() || event.get('createdAt')?.toISOString(),
      reviewed: event.get('reviewed') || false,
    };
  }));

  return { alerts, total };
});

/**
 * Mark a security alert as reviewed.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('reviewSecurityAlert', async (request) => {
  requirePermission(request, 'reviewComplianceEvent');

  const { alertId, notes } = request.params;

  if (!alertId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'alertId required');
  }

  const event = await new Parse.Query('ComplianceEvent').get(alertId, { useMasterKey: true });

  event.set('reviewed', true);
  event.set('reviewedBy', request.user.id);
  event.set('reviewedAt', new Date());
  event.set('reviewNotes', notes);

  await event.save(null, { useMasterKey: true });

  // Audit log
  await logPermissionCheck(request, 'reviewSecurityAlert', 'ComplianceEvent', alertId);

  return { success: true };
});

console.log('Security Cloud Functions loaded');
