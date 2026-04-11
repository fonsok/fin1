// ============================================================================
// Parse Cloud Code
// triggers/support.js - Support Ticket Triggers
// ============================================================================

'use strict';

Parse.Cloud.beforeSave('SatisfactionSurvey', (request) => {
  const o = request.object;
  const uid = o.get('userId') || o.get('customerId');
  if (uid) {
    o.set('userId', uid);
  }
  if (o.get('customerId') !== undefined) {
    o.unset('customerId');
  }
});

Parse.Cloud.beforeSave('SupportTicket', async (request) => {
  const ticket = request.object;
  const isNew = !ticket.existed();

  // Canonical end-customer reference: userId = Parse _User.objectId only.
  // Legacy rows may have customerId on the ticket (same meaning); migrate and drop it.
  const legacyTicketCustomer = ticket.get('customerId');
  const endUserId = ticket.get('userId') || legacyTicketCustomer;
  if (endUserId) {
    ticket.set('userId', endUserId);
  }
  if (legacyTicketCustomer !== undefined) {
    ticket.unset('customerId');
  }

  if (isNew && !ticket.get('userId')) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY,
      'SupportTicket requires userId (Parse User objectId of the customer)');
  }

  if (isNew) {
    // Generate ticket number
    if (!ticket.get('ticketNumber')) {
      const year = new Date().getFullYear();
      const lastTicket = await new Parse.Query('SupportTicket')
        .startsWith('ticketNumber', `TKT-${year}-`)
        .descending('ticketNumber')
        .first({ useMasterKey: true });

      let seq = 1;
      if (lastTicket) {
        const parts = lastTicket.get('ticketNumber').split('-');
        seq = parseInt(parts[2], 10) + 1;
      }

      ticket.set('ticketNumber', `TKT-${year}-${seq.toString().padStart(5, '0')}`);
    }

    // Set defaults (do not overwrite explicit status from imports / seeds)
    if (!ticket.get('status')) {
      ticket.set('status', 'open');
    }
    ticket.set('priority', ticket.get('priority') || 'medium');
    ticket.set('escalationLevel', 0);
    ticket.set('reopenCount', 0);
  }

  // Validate priority
  const validPriorities = ['low', 'medium', 'high', 'urgent'];
  if (!validPriorities.includes(ticket.get('priority'))) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid priority');
  }

  // Validate category
  const validCategories = ['general', 'account_issue', 'technical_issue', 'billing',
    'investment', 'trading_question', 'security', 'feedback', 'complaint', 'kyc', 'fraud_report'];
  if (!validCategories.includes(ticket.get('category'))) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid category');
  }
});

Parse.Cloud.afterSave('SupportTicket', async (request) => {
  const ticket = request.object;
  const isNew = !request.original;
  const endUserId = ticket.get('userId');

  if (isNew && endUserId) {
    // Create SLA tracking
    const SLA = Parse.Object.extend('TicketSLATracking');
    const sla = new SLA();
    sla.set('ticketId', ticket.id);

    // Calculate SLA targets based on priority
    const now = new Date();
    const priority = ticket.get('priority');
    const slaHours = { urgent: { first: 1, resolution: 4 }, high: { first: 4, resolution: 24 },
      medium: { first: 8, resolution: 48 }, low: { first: 24, resolution: 72 } };

    const targets = slaHours[priority] || slaHours.medium;

    const firstResponseTarget = new Date(now.getTime() + targets.first * 60 * 60 * 1000);
    const resolutionTarget = new Date(now.getTime() + targets.resolution * 60 * 60 * 1000);

    sla.set('firstResponseTarget', firstResponseTarget);
    sla.set('resolutionTarget', resolutionTarget);
    sla.set('slaStatus', 'on_track');
    await sla.save(null, { useMasterKey: true });

    // Notify customer
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', endUserId);
    notif.set('type', 'ticket_created');
    notif.set('category', 'support');
    notif.set('title', 'Ticket erstellt');
    notif.set('message', `Ihr Support-Ticket ${ticket.get('ticketNumber')} wurde erstellt.`);
    notif.set('referenceType', 'ticket');
    notif.set('referenceId', ticket.id);
    notif.set('isRead', false);
    await notif.save(null, { useMasterKey: true });
  }

  // Status change
  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = ticket.get('status');

    if (oldStatus !== newStatus) {
      if (newStatus === 'resolved') {
        ticket.set('resolvedAt', new Date());

        const uid = ticket.get('userId');
        if (uid) {
          // Create satisfaction survey
          const Survey = Parse.Object.extend('SatisfactionSurvey');
          const survey = new Survey();
          survey.set('ticketId', ticket.id);
          survey.set('userId', uid);
          survey.set('agentId', ticket.get('assignedTo'));
          survey.set('status', 'pending');
          survey.set('sentAt', new Date());
          survey.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)); // 7 days
          await survey.save(null, { useMasterKey: true });

          // Notify customer
          const Notification = Parse.Object.extend('Notification');
          const notif = new Notification();
          notif.set('userId', uid);
          notif.set('type', 'ticket_resolved');
          notif.set('category', 'support');
          notif.set('title', 'Ticket gelöst');
          notif.set('message', `Ihr Ticket ${ticket.get('ticketNumber')} wurde gelöst.`);
          notif.set('isRead', false);
          await notif.save(null, { useMasterKey: true });
        }
      }
    }
  }
});
