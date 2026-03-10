'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

// ============================================================================
// LEGACY TICKETS (Admin Portal)
// ============================================================================

/**
 * Get tickets list with filters
 */
Parse.Cloud.define('getTickets', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'getTickets');

  const { status, priority, category, assignedTo, userId, limit = 50, skip = 0 } = request.params;

  const Ticket = Parse.Object.extend('SupportTicket');
  const query = new Parse.Query(Ticket);

  if (status) {
    query.equalTo('status', status);
  }
  if (priority) {
    query.equalTo('priority', priority);
  }
  if (category) {
    query.equalTo('category', category);
  }
  if (assignedTo) {
    query.equalTo('assignedTo', assignedTo);
  }
  if (userId) {
    query.equalTo('userId', userId);
  }

  query.descending('createdAt');
  query.limit(limit);
  query.skip(skip);

  const [tickets, total] = await Promise.all([
    query.find({ useMasterKey: true }),
    query.count({ useMasterKey: true }),
  ]);

  // Enrich with user emails
  const enrichedTickets = await Promise.all(
    tickets.map(async (ticket) => {
      const ticketData = ticket.toJSON();

      // Get user email if userId exists
      if (ticketData.userId) {
        try {
          const userQuery = new Parse.Query(Parse.User);
          const user = await userQuery.get(ticketData.userId, { useMasterKey: true });
          ticketData.userEmail = user.get('email');
        } catch (e) {
          // User not found, skip
        }
      }

      // Get assigned admin name
      if (ticketData.assignedTo) {
        try {
          const adminQuery = new Parse.Query(Parse.User);
          const admin = await adminQuery.get(ticketData.assignedTo, { useMasterKey: true });
          ticketData.assignedToName = admin.get('firstName') + ' ' + admin.get('lastName');
        } catch (e) {
          // Admin not found, skip
        }
      }

      return ticketData;
    })
  );

  return {
    tickets: enrichedTickets,
    total,
  };
});

/**
 * Get single ticket details
 */
Parse.Cloud.define('getTicket', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'getTicketDetails');

  const { ticketId } = request.params;
  if (!ticketId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId required');
  }

  const Ticket = Parse.Object.extend('SupportTicket');
  const query = new Parse.Query(Ticket);
  const ticket = await query.get(ticketId, { useMasterKey: true });

  const ticketData = ticket.toJSON();

  // Get messages
  const Message = Parse.Object.extend('TicketMessage');
  const msgQuery = new Parse.Query(Message);
  msgQuery.equalTo('ticketId', ticketId);
  msgQuery.ascending('createdAt');
  const messages = await msgQuery.find({ useMasterKey: true });

  ticketData.messages = messages.map((m) => m.toJSON());

  return ticketData;
});

/**
 * Update ticket status or assignment
 */
Parse.Cloud.define('updateTicket', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'updateTicket');

  const { ticketId, status, priority, assignedTo, internalNotes } = request.params;
  if (!ticketId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId required');
  }

  const Ticket = Parse.Object.extend('SupportTicket');
  const query = new Parse.Query(Ticket);
  const ticket = await query.get(ticketId, { useMasterKey: true });

  if (status) ticket.set('status', status);
  if (priority) ticket.set('priority', priority);
  if (assignedTo !== undefined) ticket.set('assignedTo', assignedTo);
  if (internalNotes) ticket.set('internalNotes', internalNotes);

  ticket.set('updatedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  return ticket.toJSON();
});

/**
 * Reply to a ticket
 */
Parse.Cloud.define('replyToTicket', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'addTicketComment');

  const { ticketId, message, isInternal } = request.params;
  if (!ticketId || !message) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId and message required');
  }

  // Create message
  const Message = Parse.Object.extend('TicketMessage');
  const msg = new Message();
  msg.set('ticketId', ticketId);
  msg.set('message', message);
  msg.set('senderId', request.user.id);
  msg.set('senderRole', request.user.get('role'));
  msg.set('isInternal', !!isInternal);
  await msg.save(null, { useMasterKey: true });

  // Update ticket status if it was waiting
  const Ticket = Parse.Object.extend('SupportTicket');
  const query = new Parse.Query(Ticket);
  const ticket = await query.get(ticketId, { useMasterKey: true });

  if (ticket.get('status') === 'waiting' && !isInternal) {
    ticket.set('status', 'in_progress');
  }
  ticket.set('lastReplyAt', new Date());
  ticket.set('lastReplyBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  return msg.toJSON();
});

