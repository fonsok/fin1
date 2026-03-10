'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

// ============================================================================
// CSR PORTAL - TICKETS
// ============================================================================

/**
 * Get support tickets (CSR version with enhanced filters)
 */
Parse.Cloud.define('getSupportTickets', async (request) => {
  requireAdminRole(request);

  const { customerId, status, priority, limit = 50 } = request.params;

  const query = new Parse.Query('SupportTicket');

  if (customerId) {
    query.equalTo('userId', customerId);
  }
  if (status) {
    query.equalTo('status', status);
  }
  if (priority) {
    query.equalTo('priority', priority);
  }

  query.descending('createdAt');
  query.limit(limit);

  const tickets = await query.find({ useMasterKey: true });

  // Enrich tickets
  const enrichedTickets = await Promise.all(
    tickets.map(async (ticket) => {
      const data = ticket.toJSON();

      // Get user info
      if (data.userId) {
        try {
          const userQuery = new Parse.Query(Parse.User);
          const user = await userQuery.get(data.userId, { useMasterKey: true });
          data.userEmail = user.get('email');
          data.userName = `${user.get('firstName') || ''} ${user.get('lastName') || ''}`.trim();
        } catch (e) {
          // User not found
        }
      }

      // Get assigned agent info
      if (data.assignedTo) {
        try {
          const agentQuery = new Parse.Query(Parse.User);
          const agent = await agentQuery.get(data.assignedTo, { useMasterKey: true });
          data.assignedToName = `${agent.get('firstName') || ''} ${agent.get('lastName') || ''}`.trim();
        } catch (e) {
          // Agent not found
        }
      }

      return data;
    })
  );

  return { tickets: enrichedTickets };
});

/**
 * Create a support ticket
 */
Parse.Cloud.define('createSupportTicket', async (request) => {
  requireAdminRole(request);

  const { customerId, userId, subject, description, category, priority = 'medium' } = request.params;

  if (!subject || !description) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'subject and description required');
  }

  const actualUserId = customerId || userId;

  const Ticket = Parse.Object.extend('SupportTicket');
  const ticket = new Ticket();

  // Generate ticket number
  const ticketNumber = `TKT-${Date.now().toString(36).toUpperCase()}`;

  ticket.set('ticketNumber', ticketNumber);
  ticket.set('subject', subject);
  ticket.set('description', description);
  ticket.set('category', category || 'other');
  ticket.set('priority', priority);
  ticket.set('status', 'open');
  ticket.set('userId', actualUserId);
  ticket.set('createdBy', request.user.id);

  await ticket.save(null, { useMasterKey: true });

  return ticket.toJSON();
});

/**
 * Respond to a ticket
 */
Parse.Cloud.define('respondToTicket', async (request) => {
  requireAdminRole(request);

  const { ticketId, response, isInternal = false } = request.params;

  if (!ticketId || !response) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId and response required');
  }

  // Create message
  const Message = Parse.Object.extend('TicketMessage');
  const msg = new Message();
  msg.set('ticketId', ticketId);
  msg.set('message', response);
  msg.set('senderId', request.user.id);
  msg.set('senderName', `${request.user.get('firstName') || ''} ${request.user.get('lastName') || ''}`.trim());
  msg.set('isInternal', isInternal);
  await msg.save(null, { useMasterKey: true });

  // Update ticket
  const query = new Parse.Query('SupportTicket');
  const ticket = await query.get(ticketId, { useMasterKey: true });

  if (ticket.get('status') === 'open') {
    ticket.set('status', 'in_progress');
  }
  ticket.set('lastResponseAt', new Date());
  await ticket.save(null, { useMasterKey: true });

  return { success: true };
});

/**
 * Assign ticket to agent
 */
Parse.Cloud.define('assignTicket', async (request) => {
  requireAdminRole(request);

  const { ticketId, agentId } = request.params;

  if (!ticketId || !agentId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId and agentId required');
  }

  const query = new Parse.Query('SupportTicket');
  const ticket = await query.get(ticketId, { useMasterKey: true });

  ticket.set('assignedTo', agentId);
  if (ticket.get('status') === 'open') {
    ticket.set('status', 'in_progress');
  }
  await ticket.save(null, { useMasterKey: true });

  return { success: true };
});

/**
 * Escalate ticket
 */
Parse.Cloud.define('escalateTicket', async (request) => {
  requireAdminRole(request);

  const { ticketId, reason } = request.params;

  if (!ticketId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId required');
  }

  const query = new Parse.Query('SupportTicket');
  const ticket = await query.get(ticketId, { useMasterKey: true });

  ticket.set('escalated', true);
  ticket.set('escalationReason', reason);
  ticket.set('escalatedAt', new Date());
  ticket.set('escalatedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  return { success: true };
});

/**
 * Resolve ticket
 */
Parse.Cloud.define('resolveTicket', async (request) => {
  requireAdminRole(request);

  const { ticketId, resolutionNote } = request.params;

  if (!ticketId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId required');
  }

  const query = new Parse.Query('SupportTicket');
  const ticket = await query.get(ticketId, { useMasterKey: true });

  ticket.set('status', 'resolved');
  ticket.set('resolutionNote', resolutionNote);
  ticket.set('resolvedAt', new Date());
  ticket.set('resolvedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  return { success: true };
});

/**
 * Close ticket
 */
Parse.Cloud.define('closeTicket', async (request) => {
  requireAdminRole(request);

  const { ticketId, closureReason } = request.params;

  if (!ticketId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId required');
  }

  const query = new Parse.Query('SupportTicket');
  const ticket = await query.get(ticketId, { useMasterKey: true });

  ticket.set('status', 'closed');
  ticket.set('closureReason', closureReason);
  ticket.set('closedAt', new Date());
  ticket.set('closedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  return { success: true };
});
