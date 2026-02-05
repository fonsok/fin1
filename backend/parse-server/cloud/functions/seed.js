// ============================================================================
// Parse Cloud Functions - Seed Data for Development
// ============================================================================

'use strict';

const { requireAdminRole } = require('../utils/permissions');

/**
 * Seed mock tickets for development/testing
 * Call this once to populate the database with test data
 */
Parse.Cloud.define('seedMockTickets', async (request) => {
  requireAdminRole(request);

  // Check if tickets already exist
  const existingQuery = new Parse.Query('Ticket');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} tickets already exist. Delete them first if you want to reseed.`,
      created: 0
    };
  }

  // Mock ticket data (matching iOS app mock data)
  const mockTickets = [
    {
      ticketNumber: 'TKT-12345',
      customerId: 'CUST-INV-001',
      customerName: 'Max Investor',
      subject: 'Frage zu meiner Investition',
      description: 'Ich habe eine Frage bezüglich meiner Investition INV-2024-001.',
      status: 'open',
      priority: 'medium',
      category: 'investment',
      assignedTo: null,
      createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
    },
    {
      ticketNumber: 'TKT-12346',
      customerId: 'CUST-INV-002',
      customerName: 'Sarah Smith',
      subject: 'Problem beim Login',
      description: 'Ich kann mich nicht mehr in mein Konto einloggen.',
      status: 'in_progress',
      priority: 'high',
      category: 'account',
      assignedTo: 'csr1@test.com',
      createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // 1 day ago
    },
    {
      ticketNumber: 'TKT-12347',
      customerId: 'CUST-INV-003',
      customerName: 'Michael Johnson',
      subject: 'Rechnung nicht erhalten',
      description: 'Ich habe meine monatliche Rechnung nicht per E-Mail erhalten.',
      status: 'in_progress',
      priority: 'medium',
      category: 'billing',
      assignedTo: 'csr2@test.com',
      createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
    },
    {
      ticketNumber: 'TKT-12348',
      customerId: 'CUST-INV-001',
      customerName: 'Max Investor',
      subject: 'App stürzt beim Öffnen ab',
      description: 'Die App stürzt jedes Mal ab, wenn ich sie öffne. iOS 17.2.',
      status: 'in_progress',
      priority: 'high',
      category: 'technical',
      assignedTo: 'csr3@test.com',
      createdAt: new Date(Date.now() - 1.5 * 24 * 60 * 60 * 1000), // 1.5 days ago
    },
    {
      ticketNumber: 'TKT-12349',
      customerId: 'CUST-TRD-001',
      customerName: 'Thomas Trader',
      subject: 'Auszahlung ausstehend',
      description: 'Meine Auszahlung ist seit 5 Tagen ausstehend.',
      status: 'open',
      priority: 'urgent',
      category: 'billing',
      assignedTo: null,
      createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000), // 5 days ago
    },
    {
      ticketNumber: 'TKT-12350',
      customerId: 'CUST-TRD-002',
      customerName: 'Alex Chen',
      subject: 'KYC-Dokumente abgelehnt',
      description: 'Meine KYC-Dokumente wurden abgelehnt, aber ich verstehe nicht warum.',
      status: 'waiting',
      priority: 'medium',
      category: 'kyc',
      assignedTo: 'csr1@test.com',
      createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000), // 4 days ago
    },
    {
      ticketNumber: 'TKT-12351',
      customerId: 'CUST-INV-004',
      customerName: 'Emma Williams',
      subject: 'Passwort vergessen',
      description: 'Ich habe mein Passwort vergessen und die Reset-E-Mail kommt nicht an.',
      status: 'resolved',
      priority: 'low',
      category: 'account',
      assignedTo: 'csr2@test.com',
      createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000), // 7 days ago
      resolvedAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000), // 6 days ago
    },
    {
      ticketNumber: 'TKT-12352',
      customerId: 'CUST-INV-005',
      customerName: 'David Brown',
      subject: 'Falsche Gebührenberechnung',
      description: 'Mir wurden 50€ zu viel an Gebühren berechnet.',
      status: 'open',
      priority: 'high',
      category: 'billing',
      assignedTo: null,
      createdAt: new Date(Date.now() - 0.5 * 24 * 60 * 60 * 1000), // 12 hours ago
    },
  ];

  const Ticket = Parse.Object.extend('Ticket');
  const created = [];

  for (const ticketData of mockTickets) {
    const ticket = new Ticket();

    ticket.set('ticketNumber', ticketData.ticketNumber);
    ticket.set('customerId', ticketData.customerId);
    ticket.set('customerName', ticketData.customerName);
    ticket.set('subject', ticketData.subject);
    ticket.set('description', ticketData.description);
    ticket.set('status', ticketData.status);
    ticket.set('priority', ticketData.priority);
    ticket.set('category', ticketData.category);
    ticket.set('assignedTo', ticketData.assignedTo);

    // Set timestamps
    if (ticketData.createdAt) {
      ticket.set('createdAt', ticketData.createdAt);
    }
    if (ticketData.resolvedAt) {
      ticket.set('resolvedAt', ticketData.resolvedAt);
    }

    await ticket.save(null, { useMasterKey: true });
    created.push(ticketData.ticketNumber);
  }

  console.log(`Seeded ${created.length} mock tickets`);

  return {
    success: true,
    message: `Created ${created.length} mock tickets`,
    created: created.length,
    tickets: created,
  };
});

/**
 * Seed mock compliance events for development/testing
 */
Parse.Cloud.define('seedMockComplianceEvents', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('ComplianceEvent');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} events already exist.`,
      created: 0
    };
  }

  const mockEvents = [
    {
      eventType: 'large_transaction',
      severity: 'high',
      description: 'Transaktion über 10.000€ erkannt',
      userId: 'CUST-INV-001',
      reviewed: false,
    },
    {
      eventType: 'aml_check_failed',
      severity: 'critical',
      description: 'AML-Prüfung fehlgeschlagen - Name auf Watchlist',
      userId: 'CUST-TRD-002',
      reviewed: false,
    },
    {
      eventType: 'suspicious_activity',
      severity: 'medium',
      description: 'Mehrere Login-Versuche von verschiedenen IPs',
      userId: 'CUST-INV-003',
      reviewed: true,
      reviewedBy: 'admin@test.com',
      reviewNotes: 'Benutzer hat VPN verwendet - kein Verdacht',
    },
    {
      eventType: 'login_from_new_device',
      severity: 'low',
      description: 'Login von neuem Gerät: iPhone 15 Pro',
      userId: 'CUST-INV-004',
      reviewed: false,
    },
    {
      eventType: 'failed_login_attempt',
      severity: 'medium',
      description: '5 fehlgeschlagene Login-Versuche in 10 Minuten',
      userId: 'CUST-TRD-001',
      reviewed: false,
    },
  ];

  const Event = Parse.Object.extend('ComplianceEvent');
  let created = 0;

  for (const eventData of mockEvents) {
    const event = new Event();
    Object.keys(eventData).forEach(key => {
      event.set(key, eventData[key]);
    });
    await event.save(null, { useMasterKey: true });
    created++;
  }

  return {
    success: true,
    message: `Created ${created} mock compliance events`,
    created,
  };
});

/**
 * Seed mock audit logs for development/testing
 */
Parse.Cloud.define('seedMockAuditLogs', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('AuditLog');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} logs already exist.`,
      created: 0
    };
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
    Object.keys(logData).forEach(key => {
      log.set(key, logData[key]);
    });
    await log.save(null, { useMasterKey: true });
    created++;
  }

  return {
    success: true,
    message: `Created ${created} mock audit logs`,
    created,
  };
});

/**
 * Seed all mock data at once
 */
Parse.Cloud.define('seedAllMockData', async (request) => {
  requireAdminRole(request);

  const results = {};

  // Seed tickets
  try {
    results.tickets = await Parse.Cloud.run('seedMockTickets', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.tickets = { success: false, error: e.message };
  }

  // Seed compliance events
  try {
    results.complianceEvents = await Parse.Cloud.run('seedMockComplianceEvents', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.complianceEvents = { success: false, error: e.message };
  }

  // Seed audit logs
  try {
    results.auditLogs = await Parse.Cloud.run('seedMockAuditLogs', {}, { sessionToken: request.user.getSessionToken() });
  } catch (e) {
    results.auditLogs = { success: false, error: e.message };
  }

  return results;
});

console.log('Seed Functions loaded');
