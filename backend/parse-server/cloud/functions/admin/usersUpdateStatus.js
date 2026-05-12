'use strict';

const { PROTECTED_ADMIN_ROLES, DEACTIVATING_STATUSES } = require('./usersConstants');

async function handleUpdateUserStatus(request) {
  const { userId, status, reason } = request.params;

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const actorUserId = request.user && request.user.id;
  const targetRole = user.get('role');

  if (actorUserId && actorUserId === userId && DEACTIVATING_STATUSES.includes(status)) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Self-suspension is not allowed');
  }

  if (PROTECTED_ADMIN_ROLES.includes(targetRole) && DEACTIVATING_STATUSES.includes(status)) {
    const activeAdminQuery = new Parse.Query(Parse.User);
    activeAdminQuery.containedIn('role', PROTECTED_ADMIN_ROLES);
    activeAdminQuery.notContainedIn('status', DEACTIVATING_STATUSES);
    const activeAdminCount = await activeAdminQuery.count({ useMasterKey: true });
    if (activeAdminCount <= 1) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cannot suspend the last active admin');
    }
  }

  const oldStatus = user.get('status');
  user.set('status', status);
  user.set('statusReason', reason);
  user.set('statusChangedAt', new Date());
  user.set('statusChangedBy', request.user.id);

  await user.save(null, { useMasterKey: true });

  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'action');
  log.set('action', 'update_user_status');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'User');
  log.set('resourceId', userId);
  log.set('oldValues', { status: oldStatus });
  log.set('newValues', { status, reason });
  log.set('metadata', {
    performedBy: request.user.id,
    performedByRole: request.user.get('role'),
  });
  await log.save(null, { useMasterKey: true });

  return { success: true, oldStatus, newStatus: status };
}

module.exports = {
  handleUpdateUserStatus,
};
