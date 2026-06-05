'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');
const { applyQuerySort } = require('../../utils/applyQuerySort');
const {
  listTickets,
  getTicketDetail,
  mapTicketForClient,
  normalizeStatusForStorage,
  assertValidStatus,
  validateStatusTransition,
  logTicketAudit,
} = require('../../utils/supportTicketHelper');

// ============================================================================
// TICKETS (Admin + CSR list/detail)
// ============================================================================

/**
 * Get tickets list with filters (paginated, batch-enriched)
 */
Parse.Cloud.define('getTickets', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'getTickets');

  return listTickets(request.params || {});
});

/**
 * Get single ticket details (comments mapped from TicketMessage)
 */
Parse.Cloud.define('getTicket', async (request) => {
  requireAdminRole(request);
  requirePermission(request, 'getTicketDetails');

  const { ticketId } = request.params;
  if (!ticketId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'ticketId required');
  }

  return getTicketDetail(ticketId);
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
  const ticket = await new Parse.Query(Ticket).get(ticketId, { useMasterKey: true });
  const oldStatus = ticket.get('status');
  const oldAssigned = ticket.get('assignedTo');

  if (status) {
    assertValidStatus(status);
    validateStatusTransition(oldStatus, status);
    ticket.set('status', normalizeStatusForStorage(status));
  }
  if (priority) ticket.set('priority', priority);
  if (assignedTo !== undefined) ticket.set('assignedTo', assignedTo);
  if (internalNotes) ticket.set('internalNotes', internalNotes);

  ticket.set('updatedBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId,
    action: 'ticket_updated',
    oldValues: { status: oldStatus, assignedTo: oldAssigned },
    newValues: { status: ticket.get('status'), assignedTo: ticket.get('assignedTo') },
  });

  return mapTicketForClient(ticket.toJSON());
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

  const Message = Parse.Object.extend('TicketMessage');
  const msg = new Message();
  msg.set('ticketId', ticketId);
  msg.set('message', message);
  msg.set('senderId', request.user.id);
  msg.set('senderRole', request.user.get('role'));
  msg.set('isInternal', !!isInternal);
  await msg.save(null, { useMasterKey: true });

  const Ticket = Parse.Object.extend('SupportTicket');
  const ticket = await new Parse.Query(Ticket).get(ticketId, { useMasterKey: true });
  const oldStatus = ticket.get('status');

  if ((oldStatus === 'waiting' || oldStatus === 'waiting_for_customer') && !isInternal) {
    ticket.set('status', 'in_progress');
  }
  ticket.set('lastReplyAt', new Date());
  ticket.set('lastReplyBy', request.user.id);
  await ticket.save(null, { useMasterKey: true });

  await logTicketAudit({
    actorId: request.user.id,
    actorRole: request.user.get('role'),
    ticketId,
    action: isInternal ? 'ticket_internal_note' : 'ticket_reply',
    oldValues: { status: oldStatus },
    newValues: { status: ticket.get('status') },
    metadata: { isInternal: !!isInternal },
  });

  return msg.toJSON();
});
