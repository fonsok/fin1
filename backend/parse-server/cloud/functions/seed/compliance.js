'use strict';

/**
 * Mock compliance / audit data must be created only via the Parse SDK (save with useMasterKey).
 * Raw Mongo inserts (e.g. BSON ObjectId as _id without a valid Parse objectId string) break
 * Parse deletes and surface as AGGREGATE_ERROR (600) during batch destroy.
 */

const { requireAdminRole } = require('../../utils/permissions');
const { firstUser, userIdFromCustomerId, adminUserId } = require('./helpers');

Parse.Cloud.define('seedMockComplianceEvents', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('ComplianceEvent');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return { success: false, message: `${existingCount} events already exist.`, created: 0 };
  }

  const year = new Date().getFullYear();
  const cid = (prefix, n) => `${prefix}-${year}-${String(n).padStart(5, '0')}`;
  const anl = n => cid('ANL', n);
  const trd = n => cid('TRD', n);

  const reviewerId = await adminUserId();

  const templates = [
    { eventType: 'large_transaction', severity: 'high', description: 'Transaktion über 10.000€ erkannt', customerId: anl(1), reviewed: false },
    { eventType: 'aml_check_failed', severity: 'critical', description: 'AML-Prüfung fehlgeschlagen - Name auf Watchlist', customerId: trd(2), reviewed: false },
    {
      eventType: 'suspicious_activity',
      severity: 'medium',
      description: 'Mehrere Login-Versuche von verschiedenen IPs',
      customerId: anl(3),
      reviewed: true,
      reviewNotes: 'Benutzer hat VPN verwendet - kein Verdacht',
    },
    { eventType: 'login_from_new_device', severity: 'low', description: 'Login von neuem Gerät: iPhone 15 Pro', customerId: anl(4), reviewed: false },
    { eventType: 'failed_login_attempt', severity: 'medium', description: '5 fehlgeschlagene Login-Versuche in 10 Minuten', customerId: trd(1), reviewed: false },
  ];

  const Event = Parse.Object.extend('ComplianceEvent');
  let created = 0;
  const baseTime = Date.now();
  for (let i = 0; i < templates.length; i++) {
    const row = templates[i];
    const userId = await userIdFromCustomerId(row.customerId);
    const occurredAt = new Date(baseTime - (templates.length - i) * 3600000);

    const event = new Event();
    event.set('userId', userId);
    event.set('eventType', row.eventType);
    event.set('severity', row.severity);
    event.set('description', row.description);
    event.set('metadata', { seed: true, source: 'seedMockComplianceEvents' });
    event.set('occurredAt', occurredAt);
    event.set('reviewed', row.reviewed === true);
    if (row.reviewed) {
      if (reviewerId) event.set('reviewedBy', reviewerId);
      event.set('reviewedAt', new Date(baseTime - 86400000));
      if (row.reviewNotes) event.set('reviewNotes', row.reviewNotes);
    }
    await event.save(null, { useMasterKey: true });
    created++;
  }
  return { success: true, message: `Created ${created} mock compliance events`, created };
});

Parse.Cloud.define('seedMockAuditLogs', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('AuditLog');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return { success: false, message: `${existingCount} logs already exist.`, created: 0 };
  }

  const year = new Date().getFullYear();
  const anl = n => `ANL-${year}-${String(n).padStart(5, '0')}`;
  const trd = n => `TRD-${year}-${String(n).padStart(5, '0')}`;

  const adminId = await adminUserId();
  const csr = await firstUser({ email: 'csr1@test.com' });
  const csrId = csr ? csr.id : 'csr1@test.com';

  const inv1Id = await userIdFromCustomerId(anl(1));
  const inv3Id = await userIdFromCustomerId(anl(3));
  const trd2Id = await userIdFromCustomerId(trd(2));

  const actorAdmin = adminId || 'admin@test.com';
  const mockLogs = [
    { logType: 'security', action: 'login', userId: actorAdmin },
    { logType: 'security', action: '2fa_totp_success', userId: actorAdmin },
    { logType: 'admin', action: 'user_updated', userId: actorAdmin, resourceType: 'User', resourceId: inv1Id },
    { logType: 'admin', action: 'status_changed', userId: csrId, resourceType: 'User', resourceId: trd2Id, metadata: { oldStatus: 'active', newStatus: 'suspended' } },
    { logType: 'compliance', action: 'compliance_event_reviewed', userId: actorAdmin, resourceType: 'ComplianceEvent' },
    { logType: 'security', action: 'password_changed', userId: inv3Id },
    { logType: 'user', action: 'login', userId: inv1Id },
    { logType: 'user', action: 'logout', userId: inv1Id },
  ];

  const AuditLog = Parse.Object.extend('AuditLog');
  let created = 0;
  for (const logData of mockLogs) {
    const log = new AuditLog();
    Object.keys(logData).forEach(key => log.set(key, logData[key]));
    await log.save(null, { useMasterKey: true });
    created++;
  }
  return { success: true, message: `Created ${created} mock audit logs`, created };
});
