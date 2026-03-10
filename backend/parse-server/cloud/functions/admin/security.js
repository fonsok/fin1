'use strict';

const { requirePermission, logPermissionCheck } = require('../../utils/permissions');

Parse.Cloud.define('getSecurityDashboard', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const now = new Date();
  const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const last7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const failedLoginQuery = new Parse.Query('ComplianceEvent');
  failedLoginQuery.equalTo('eventType', 'failed_login_attempt');
  failedLoginQuery.greaterThanOrEqualTo('occurredAt', last24h);
  const failedLogins = await failedLoginQuery.count({ useMasterKey: true });

  const suspiciousQuery = new Parse.Query('ComplianceEvent');
  suspiciousQuery.containedIn('eventType', ['suspicious_activity', 'login_from_new_device']);
  suspiciousQuery.greaterThanOrEqualTo('occurredAt', last7d);
  const suspiciousActivities = await suspiciousQuery.count({ useMasterKey: true });

  const lockedQuery = new Parse.Query(Parse.User);
  lockedQuery.equalTo('status', 'locked');
  const lockedAccounts = await lockedQuery.count({ useMasterKey: true });

  const reviewQuery = new Parse.Query('ComplianceEvent');
  reviewQuery.equalTo('requiresReview', true);
  reviewQuery.equalTo('reviewed', false);
  reviewQuery.containedIn('eventType', [
    'suspicious_activity',
    'failed_login_attempt',
    'login_from_new_device',
    'aml_check_failed'
  ]);
  const pendingSecurityReviews = await reviewQuery.count({ useMasterKey: true });

  return {
    failedLogins: { last24h: failedLogins },
    suspiciousActivities: { last7d: suspiciousActivities },
    accounts: { locked: lockedAccounts },
    reviews: { pending: pendingSecurityReviews },
  };
});

Parse.Cloud.define('getLoginHistory', async (request) => {
  requirePermission(request, 'getLoginHistory');

  const { userId, limit = 50 } = request.params;

  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const query = new Parse.Query('ComplianceEvent');
  query.equalTo('userId', userId);
  query.containedIn('eventType', [
    'account_created',
    'login_from_new_device',
    'failed_login_attempt',
    'password_changed',
    'two_factor_enabled'
  ]);
  query.descending('occurredAt');
  query.limit(limit);

  const events = await query.find({ useMasterKey: true });

  await logPermissionCheck(request, 'getLoginHistory', 'User', userId);

  return { events: events.map(e => e.toJSON()) };
});

Parse.Cloud.define('terminateUserSession', async (request) => {
  requirePermission(request, 'terminateUserSession');

  const { userId, reason } = request.params;

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason required');
  }

  const sessionQuery = new Parse.Query(Parse.Session);
  const userPointer = new Parse.User();
  userPointer.id = userId;
  sessionQuery.equalTo('user', userPointer);

  const sessions = await sessionQuery.find({ useMasterKey: true });

  await Parse.Object.destroyAll(sessions, { useMasterKey: true });

  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'security');
  log.set('action', 'terminate_user_sessions');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('metadata', { reason, sessionsTerminated: sessions.length });
  await log.save(null, { useMasterKey: true });

  const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
  const event = new ComplianceEvent();
  event.set('userId', userId);
  event.set('eventType', 'account_suspended');
  event.set('severity', 'medium');
  event.set('description', `Sessions terminated by ${request.user.get('role')}: ${reason}`);
  event.set('metadata', {
    terminatedBy: request.user.id,
    terminatedByRole: request.user.get('role'),
    reason
  });
  await event.save(null, { useMasterKey: true });

  return {
    success: true,
    sessionsTerminated: sessions.length
  };
});

Parse.Cloud.define('forcePasswordReset', async (request) => {
  requirePermission(request, 'forcePasswordReset');

  const { userId, reason } = request.params;

  if (!userId || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId and reason required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });

  const resetToken = Math.random().toString(36).substring(2, 15) +
                     Math.random().toString(36).substring(2, 15);

  user.set('passwordResetToken', resetToken);
  user.set('passwordResetExpires', new Date(Date.now() + 24 * 60 * 60 * 1000));
  user.set('requiresPasswordChange', true);
  await user.save(null, { useMasterKey: true });

  await logPermissionCheck(request, 'forcePasswordReset', 'User', userId);

  return {
    success: true,
    message: 'Password reset initiated. User will be required to change password on next login.'
  };
});
