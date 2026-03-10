'use strict';

const { requireAdminRole } = require('../../utils/permissions');

Parse.Cloud.define('seedMockTickets', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('Ticket');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} tickets already exist. Delete them first if you want to reseed.`,
      created: 0
    };
  }

  const mockTickets = [
    { ticketNumber: 'TKT-12345', customerId: 'CUST-INV-001', customerName: 'Max Investor', subject: 'Frage zu meiner Investition', description: 'Ich habe eine Frage bezüglich meiner Investition INV-2024-001.', status: 'open', priority: 'medium', category: 'investment', assignedTo: null, createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12346', customerId: 'CUST-INV-002', customerName: 'Sarah Smith', subject: 'Problem beim Login', description: 'Ich kann mich nicht mehr in mein Konto einloggen.', status: 'in_progress', priority: 'high', category: 'account', assignedTo: 'csr1@test.com', createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12347', customerId: 'CUST-INV-003', customerName: 'Michael Johnson', subject: 'Rechnung nicht erhalten', description: 'Ich habe meine monatliche Rechnung nicht per E-Mail erhalten.', status: 'in_progress', priority: 'medium', category: 'billing', assignedTo: 'csr2@test.com', createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12348', customerId: 'CUST-INV-001', customerName: 'Max Investor', subject: 'App stürzt beim Öffnen ab', description: 'Die App stürzt jedes Mal ab, wenn ich sie öffne. iOS 17.2.', status: 'in_progress', priority: 'high', category: 'technical', assignedTo: 'csr3@test.com', createdAt: new Date(Date.now() - 1.5 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12349', customerId: 'CUST-TRD-001', customerName: 'Thomas Trader', subject: 'Auszahlung ausstehend', description: 'Meine Auszahlung ist seit 5 Tagen ausstehend.', status: 'open', priority: 'urgent', category: 'billing', assignedTo: null, createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12350', customerId: 'CUST-TRD-002', customerName: 'Alex Chen', subject: 'KYC-Dokumente abgelehnt', description: 'Meine KYC-Dokumente wurden abgelehnt, aber ich verstehe nicht warum.', status: 'waiting', priority: 'medium', category: 'kyc', assignedTo: 'csr1@test.com', createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12351', customerId: 'CUST-INV-004', customerName: 'Emma Williams', subject: 'Passwort vergessen', description: 'Ich habe mein Passwort vergessen und die Reset-E-Mail kommt nicht an.', status: 'resolved', priority: 'low', category: 'account', assignedTo: 'csr2@test.com', createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000), resolvedAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000) },
    { ticketNumber: 'TKT-12352', customerId: 'CUST-INV-005', customerName: 'David Brown', subject: 'Falsche Gebührenberechnung', description: 'Mir wurden 50€ zu viel an Gebühren berechnet.', status: 'open', priority: 'high', category: 'billing', assignedTo: null, createdAt: new Date(Date.now() - 0.5 * 24 * 60 * 60 * 1000) },
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
    if (ticketData.createdAt) ticket.set('createdAt', ticketData.createdAt);
    if (ticketData.resolvedAt) ticket.set('resolvedAt', ticketData.resolvedAt);
    await ticket.save(null, { useMasterKey: true });
    created.push(ticketData.ticketNumber);
  }

  console.log(`Seeded ${created.length} mock tickets`);
  return { success: true, message: `Created ${created.length} mock tickets`, created: created.length, tickets: created };
});
