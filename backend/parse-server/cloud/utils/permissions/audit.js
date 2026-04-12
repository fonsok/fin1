'use strict';

async function logPermissionCheck(request, permission, resourceType, resourceId) {
  try {
    const AuditLog = Parse.Object.extend('AuditLog');
    const log = new AuditLog();

    log.set('logType', 'data_access');
    log.set('action', `permission_check:${permission}`);
    log.set('userId', request.user.id);
    log.set('userRole', request.user.get('role'));
    log.set('resourceType', resourceType);
    log.set('resourceId', resourceId);
    log.set('metadata', {
      permission,
      ip: request.ip,
      userAgent: request.headers?.['user-agent'],
    });

    await log.save(null, { useMasterKey: true });
  } catch (error) {
    console.error('Failed to log permission check:', error);
  }
}

module.exports = {
  logPermissionCheck,
};
