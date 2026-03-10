'use strict';

const { requireAdminRole } = require('../../utils/permissions');

Parse.Cloud.define('seedMockComplianceEvents', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('ComplianceEvent');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return { success: false, message: `${existingCount} events already exist.`, created: 0 };
  }

  const mockEvents = [
    { eventType: 'large_transaction', severity: 'high', description: 'Transaktion über 10.000€ erkannt', userId: 'CUST-INV-001', reviewed: false },
    { eventType: 'aml_check_failed', severity: 'critical', description: 'AML-Prüfung fehlgeschlagen - Name auf Watchlist', userId: 'CUST-TRD-002', reviewed: false },
    { eventType: 'suspicious_activity', severity: 'medium', description: 'Mehrere Login-Versuche von verschiedenen IPs', userId: 'CUST-INV-003', reviewed: true, reviewedBy: 'admin@test.com', reviewNotes: 'Benutzer hat VPN verwendet - kein Verdacht' },
    { eventType: 'login_from_new_device', severity: 'low', description: 'Login von neuem Gerät: iPhone 15 Pro', userId: 'CUST-INV-004', reviewed: false },
    { eventType: 'failed_login_attempt', severity: 'medium', description: '5 fehlgeschlagene Login-Versuche in 10 Minuten', userId: 'CUST-TRD-001', reviewed: false },
  ];

  const Event = Parse.Object.extend('ComplianceEvent');
  let created = 0;
  for (const eventData of mockEvents) {
    const event = new Event();
    Object.keys(eventData).forEach(key => event.set(key, eventData[key]));
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

  const mockLogs = [
    { logType: 'security', action: 'login', userId: 'admin@test.com' },
    { logType: 'security', action: '2fa_totp_success', userId: 'admin@test.com' },
    { logType: 'admin', action: 'user_updated', userId: 'admin@test.com', resourceType: 'User', resourceId: 'CUST-INV-001' },
    { logType: 'admin', action: 'status_changed', userId: 'csr1@test.com', resourceType: 'User', resourceId: 'CUST-TRD-002' },
    { logType: 'compliance', action: 'compliance_event_reviewed', userId: 'compliance@test.com', resourceType: 'ComplianceEvent' },
    { logType: 'security', action: 'password_changed', userId: 'CUST-INV-003' },
    { logType: 'user', action: 'login', userId: 'CUST-INV-001' },
    { logType: 'user', action: 'logout', userId: 'CUST-INV-001' },
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
