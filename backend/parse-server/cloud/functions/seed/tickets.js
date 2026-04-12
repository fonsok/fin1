'use strict';

/**
 * Seeds SupportTicket (same class as Admin/CSR). Do not use legacy class "Ticket".
 * End customer: only field userId (Parse _User.objectId). businessCustomerNumber is seed lookup (ANL-/TRD-).
 * assignedTo: Parse User objectId for CSR agents when present.
 */

const { requireAdminRole } = require('../../utils/permissions');
const { userIdFromBusinessCustomerNumber, userIdFromEmailOrNull } = require('./helpers');

/** Maps old mock labels to SupportTicket.beforeSave-allowed categories. */
const CATEGORY = {
  investment: 'investment',
  account: 'account_issue',
  billing: 'billing',
  technical: 'technical_issue',
  kyc: 'kyc',
};

Parse.Cloud.define('seedMockTickets', async (request) => {
  requireAdminRole(request);

  const existingQuery = new Parse.Query('SupportTicket');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0) {
    return {
      success: false,
      message: `${existingCount} support tickets already exist. Delete them first if you want to reseed.`,
      created: 0,
    };
  }

  const year = new Date().getFullYear();
  const anl = n => `ANL-${year}-${String(n).padStart(5, '0')}`;
  const trd = n => `TRD-${year}-${String(n).padStart(5, '0')}`;

  const csr1 = await userIdFromEmailOrNull('csr1@test.com');
  const csr2 = await userIdFromEmailOrNull('csr2@test.com');
  const csr3 = await userIdFromEmailOrNull('csr3@test.com');

  const createdBy = request.user.id;

  const mockTickets = [
    {
      businessCustomerNumber: anl(1),
      subject: 'Frage zu meiner Investition',
      description: `Ich habe eine Frage bezüglich meiner Investition INV-${year}-0000001.`,
      status: 'open',
      priority: 'medium',
      categoryKey: 'investment',
      assigneeId: null,
      createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: anl(2),
      subject: 'Problem beim Login',
      description: 'Ich kann mich nicht mehr in mein Konto einloggen.',
      status: 'in_progress',
      priority: 'high',
      categoryKey: 'account',
      assigneeId: csr1,
      createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: anl(3),
      subject: 'Rechnung nicht erhalten',
      description: 'Ich habe meine monatliche Rechnung nicht per E-Mail erhalten.',
      status: 'in_progress',
      priority: 'medium',
      categoryKey: 'billing',
      assigneeId: csr2,
      createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: anl(1),
      subject: 'App stürzt beim Öffnen ab',
      description: 'Die App stürzt jedes Mal ab, wenn ich sie öffne. iOS 17.2.',
      status: 'in_progress',
      priority: 'high',
      categoryKey: 'technical',
      assigneeId: csr3,
      createdAt: new Date(Date.now() - 1.5 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: trd(1),
      subject: 'Auszahlung ausstehend',
      description: 'Meine Auszahlung ist seit 5 Tagen ausstehend.',
      status: 'open',
      priority: 'urgent',
      categoryKey: 'billing',
      assigneeId: null,
      createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: trd(2),
      subject: 'KYC-Dokumente abgelehnt',
      description: 'Meine KYC-Dokumente wurden abgelehnt, aber ich verstehe nicht warum.',
      status: 'waiting',
      priority: 'medium',
      categoryKey: 'kyc',
      assigneeId: csr1,
      createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: anl(4),
      subject: 'Passwort vergessen',
      description: 'Ich habe mein Passwort vergessen und die Reset-E-Mail kommt nicht an.',
      status: 'resolved',
      priority: 'low',
      categoryKey: 'account',
      assigneeId: csr2,
      createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
      resolvedAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000),
    },
    {
      businessCustomerNumber: anl(5),
      subject: 'Falsche Gebührenberechnung',
      description: 'Mir wurden 50€ zu viel an Gebühren berechnet.',
      status: 'open',
      priority: 'high',
      categoryKey: 'billing',
      assigneeId: null,
      createdAt: new Date(Date.now() - 0.5 * 24 * 60 * 60 * 1000),
    },
  ];

  const Ticket = Parse.Object.extend('SupportTicket');
  const ticketNumbers = [];

  for (const row of mockTickets) {
    const userId = await userIdFromBusinessCustomerNumber(row.businessCustomerNumber);
    const ticket = new Ticket();

    ticket.set('subject', row.subject);
    ticket.set('description', row.description);
    ticket.set('status', row.status);
    ticket.set('priority', row.priority);
    ticket.set('category', CATEGORY[row.categoryKey] || 'general');
    ticket.set('userId', userId);
    ticket.set('createdBy', createdBy);
    if (row.assigneeId) {
      ticket.set('assignedTo', row.assigneeId);
    }
    if (row.createdAt) {
      ticket.set('createdAt', row.createdAt);
    }
    if (row.resolvedAt) {
      ticket.set('resolvedAt', row.resolvedAt);
    }

    await ticket.save(null, { useMasterKey: true });
    ticketNumbers.push(ticket.get('ticketNumber'));
  }

  console.log(`Seeded ${ticketNumbers.length} mock SupportTickets`);
  return {
    success: true,
    message: `Created ${ticketNumbers.length} mock support tickets`,
    created: ticketNumbers.length,
    tickets: ticketNumbers,
  };
});
