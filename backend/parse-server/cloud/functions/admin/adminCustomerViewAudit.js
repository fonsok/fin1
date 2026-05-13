'use strict';

/**
 * Explizites Audit für „Kundensicht“ im Admin Web Portal (Lesemodus, kein App-Impersonate).
 * Ergänzt die bestehende data_access-Zeile aus getUserDetails um eine klar typisierte Spur.
 */
const { requirePermission } = require('../../utils/permissions');
const { readCustomerNumber } = require('../../utils/userIdentity');

function resolveClientIp(request) {
  const h = request.headers || {};
  const xf = h['x-forwarded-for'];
  if (typeof xf === 'string' && xf.length > 0) {
    return xf.split(',')[0].trim();
  }
  if (typeof h['x-real-ip'] === 'string') {
    return h['x-real-ip'];
  }
  return request.ip || '';
}

Parse.Cloud.define('logAdminCustomerView', async (request) => {
  requirePermission(request, 'getUserDetails');

  const { targetUserId, viewContext, reason } = request.params || {};
  if (!targetUserId || typeof targetUserId !== 'string') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'targetUserId required');
  }

  const safeContext =
    typeof viewContext === 'string' && viewContext.trim().length > 0
      ? viewContext.trim().slice(0, 120)
      : 'admin_portal';

  const safeReason = typeof reason === 'string' ? reason.trim().slice(0, 500) : '';

  let targetEmail = '';
  let targetCustomerNumber = '';
  try {
    const target = await new Parse.Query(Parse.User).get(targetUserId, { useMasterKey: true });
    targetEmail = target.get('email') || '';
    targetCustomerNumber = readCustomerNumber(target);
  } catch (_) {
    // Ziel-User unbekannt — trotzdem protokollieren (z. B. gelöschte IDs)
  }

  const AuditLog = Parse.Object.extend('AuditLog');
  const log = new AuditLog();
  log.set('logType', 'admin_customer_view');
  log.set('action', 'view_customer_record');
  log.set('userId', request.user.id);
  log.set('userRole', request.user.get('role'));
  log.set('resourceType', 'User');
  log.set('resourceId', targetUserId);
  log.set('metadata', {
    viewContext: safeContext,
    reason: safeReason,
    adminEmail: request.user.get('email') || '',
    targetUserId,
    targetEmail,
    targetCustomerNumber,
    ip: resolveClientIp(request),
    userAgent: request.headers?.['user-agent'] || '',
  });

  await log.save(null, { useMasterKey: true });

  return { success: true };
});
