'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const {
  listTickets,
  mapTicketForClient,
  normalizeStatusForStorage,
  assertValidStatus,
  validateStatusTransition,
  logTicketAudit,
  escalateTicketRecord,
} = require('../../utils/supportTicketHelper');

// ============================================================================
// CSR PORTAL - TICKETS
// ============================================================================

/**
 * @deprecated Prefer getTickets — kept for backward compatibility; delegates to shared list.
 */
Parse.Cloud.define('getSupportTickets', async (request) => {
  requireAdminRole(request);
  const params = { ...request.params, limit: request.params.limit || 50 };
  return listTickets(params);
});

/**
 * Create a support ticket
 */
Parse.Cloud.define('createSupportTicket', async (request) => {
  requireAdminRole(request);

  const { userId, customerId, subject, description, category, priority = 'medium' } = request.params;

  if (!subject || !description) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'subject and description required');
  }

  const actualUserId = userId || customerId;
  if (!actualUserId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY,
      'userId required (Parse User objectId of the end customer). customerId is accepted as a legacy alias only.');
  }

  const Ticket = Parse.Object.extend('SupportTicket');
  const ticket = new Ticket();

  ticket.set('subject', subject);
  ticket.set('description', description);
  ticket.set('category', category || 'general');
  ticket.set('priority', priority);
  ticket.set('status', 'open');
  ticket.set('userId', actualUserId);
  ticket.set('createdBy', request.user.id);

  await ticket.save(null, { useMasterKey: true });

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId: ticket.id,
    action: 'ticket_created',
    newValues: { status: 'open', priority, category },
    metadata: { userId: actualUserId },
  });

  const { scheduleTicketCreated } = require('../../utils/ticketEmailNotifier');
  scheduleTicketCreated(ticket);

  return mapTicketForClient(ticket.toJSON());
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

  const Message = Parse.Object.extend('TicketMessage');
  const msg = new Message();
  msg.set('ticketId', ticketId);
  msg.set('message', response);
  msg.set('senderId', request.user.id);
  msg.set('senderName', `${request.user.get('firstName') || ''} ${request.user.get('lastName') || ''}`.trim());
  msg.set('isInternal', isInternal);
  await msg.save(null, { useMasterKey: true });

  const ticket = await new Parse.Query('SupportTicket').get(ticketId, { useMasterKey: true });
  const oldStatus = ticket.get('status');

  if (oldStatus === 'open') {
    ticket.set('status', 'in_progress');
  } else if ((oldStatus === 'waiting' || oldStatus === 'waiting_for_customer') && !isInternal) {
    ticket.set('status', 'in_progress');
  }
  ticket.set('lastResponseAt', new Date());
  await ticket.save(null, { useMasterKey: true });

  if (!isInternal) {
    const customerId = ticket.get('userId');
    if (request.user.id !== customerId) {
      const slaQuery = new Parse.Query('TicketSLATracking');
      slaQuery.equalTo('ticketId', ticketId);
      const sla = await slaQuery.first({ useMasterKey: true });
      if (sla && !sla.get('firstResponseActual')) {
        sla.set('firstResponseActual', new Date());
        sla.set('slaStatus', 'on_track');
        await sla.save(null, { useMasterKey: true });
      }
    }
  }

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId,
    action: isInternal ? 'ticket_internal_note' : 'ticket_reply',
    oldValues: { status: oldStatus },
    newValues: { status: ticket.get('status') },
    metadata: { isInternal: !!isInternal },
  });

  if (!isInternal && request.user.id !== ticket.get('userId')) {
    const { scheduleTicketPublicReply } = require('../../utils/ticketEmailNotifier');
    scheduleTicketPublicReply(ticket, response, { agentId: request.user.id });
  }

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

  const ticket = await new Parse.Query('SupportTicket').get(ticketId, { useMasterKey: true });
  const oldAssigned = ticket.get('assignedTo');
  const oldStatus = ticket.get('status');

  ticket.set('assignedTo', agentId);
  if (oldStatus === 'open') {
    ticket.set('status', 'in_progress');
  }
  await ticket.save(null, { useMasterKey: true });

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId,
    action: 'ticket_assigned',
    oldValues: { assignedTo: oldAssigned, status: oldStatus },
    newValues: { assignedTo: agentId, status: ticket.get('status') },
  });

  return { success: true };
});

/**
 * Escalate ticket
 */
Parse.Cloud.define('escalateTicket', async (request) => {
  requireAdminRole(request);

  const { ticketId, reason } = request.params;

  if (!ticketId || !reason || !String(reason).trim()) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId and reason required');
  }

  const ticket = await new Parse.Query('SupportTicket').get(ticketId, { useMasterKey: true });

  await escalateTicketRecord({
    ticket,
    reason,
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    isAutomatic: false,
  });

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

  const ticket = await new Parse.Query('SupportTicket').get(ticketId, { useMasterKey: true });
  const oldStatus = ticket.get('status');
  validateStatusTransition(oldStatus, 'resolved');

  ticket.set('status', 'resolved');
  ticket.set('resolutionNote', resolutionNote);
  ticket.set('resolvedAt', new Date());
  ticket.set('resolvedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId,
    action: 'ticket_resolved',
    oldValues: { status: oldStatus },
    newValues: { status: 'resolved' },
  });

  const { scheduleTicketResolved } = require('../../utils/ticketEmailNotifier');
  scheduleTicketResolved(ticket, resolutionNote, { agentId: request.user.id });

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

  const ticket = await new Parse.Query('SupportTicket').get(ticketId, { useMasterKey: true });
  const oldStatus = ticket.get('status');
  validateStatusTransition(oldStatus, 'closed');

  ticket.set('status', 'closed');
  ticket.set('closureReason', closureReason);
  ticket.set('closedAt', new Date());
  ticket.set('closedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId,
    action: 'ticket_closed',
    oldValues: { status: oldStatus },
    newValues: { status: 'closed' },
  });

  return { success: true };
});
