'use strict';

const ACTIVE_STATUSES = ['open', 'in_progress', 'waiting_for_customer', 'waiting', 'escalated'];
const ARCHIVE_STATUSES = ['resolved', 'closed', 'archived'];
const CANONICAL_STATUSES = [...ACTIVE_STATUSES, ...ARCHIVE_STATUSES];
const MAX_LIST_LIMIT = 500;

const CLIENT_STATUS_ALIASES = {
  waiting: 'waiting_for_customer',
};

function normalizeStatusForStorage(status) {
  if (!status || typeof status !== 'string') return status;
  const key = status.toLowerCase().trim();
  return CLIENT_STATUS_ALIASES[key] || key;
}

function normalizeStatusForClient(status) {
  if (!status) return status;
  if (status === 'waiting_for_customer') return 'waiting';
  return status;
}

function isValidStatus(status) {
  const canonical = normalizeStatusForStorage(status);
  return CANONICAL_STATUSES.includes(canonical);
}

function assertValidStatus(status) {
  if (!isValidStatus(status)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid ticket status: ${status}`);
  }
}

function applyCommonFilters(query, filters) {
  const { priority, category, assignedTo, userId, fromDate, toDate } = filters;
  if (priority) query.equalTo('priority', priority);
  if (category) query.equalTo('category', category);
  if (assignedTo) query.equalTo('assignedTo', assignedTo);
  if (userId) query.equalTo('userId', userId);
  if (fromDate) query.greaterThanOrEqualTo('createdAt', new Date(fromDate));
  if (toDate) query.lessThanOrEqualTo('createdAt', new Date(toDate));
  return query;
}

function buildEscalatedQuery(Ticket, filters) {
  const byStatus = applyCommonFilters(new Parse.Query(Ticket), filters);
  byStatus.equalTo('status', 'escalated');

  const byFlag = applyCommonFilters(new Parse.Query(Ticket), filters);
  byFlag.equalTo('escalated', true);

  return Parse.Query.or(byStatus, byFlag);
}

function buildListQuery(Ticket, filters) {
  const { status, unassigned, activeOnly, archiveOnly } = filters;

  if (status === 'escalated') {
    return buildEscalatedQuery(Ticket, filters);
  }

  const query = applyCommonFilters(new Parse.Query(Ticket), filters);

  if (status) {
    const canonical = normalizeStatusForStorage(status);
    if (canonical === 'waiting_for_customer') {
      query.containedIn('status', ['waiting_for_customer', 'waiting']);
    } else {
      query.equalTo('status', canonical);
    }
  } else if (activeOnly) {
    query.containedIn('status', ACTIVE_STATUSES);
  } else if (archiveOnly) {
    query.containedIn('status', ARCHIVE_STATUSES);
  }

  if (unassigned) {
    query.doesNotExist('assignedTo');
  }

  return query;
}

async function batchLoadUsers(userIds) {
  const unique = [...new Set(userIds.filter(Boolean))];
  const map = new Map();
  if (!unique.length) return map;

  const query = new Parse.Query(Parse.User);
  query.containedIn('objectId', unique);
  query.limit(unique.length);
  const users = await query.find({ useMasterKey: true });

  users.forEach((user) => {
    const name = `${user.get('firstName') || ''} ${user.get('lastName') || ''}`.trim();
    map.set(user.id, {
      email: user.get('email'),
      name: name || user.get('email') || user.id,
    });
  });
  return map;
}

async function enrichTicketsBatch(tickets) {
  const userIds = [];
  tickets.forEach((ticket) => {
    const data = ticket.toJSON ? ticket.toJSON() : ticket;
    if (data.userId) userIds.push(data.userId);
    if (data.assignedTo) userIds.push(data.assignedTo);
    if (data.escalatedBy) userIds.push(data.escalatedBy);
    if (data.resolvedBy) userIds.push(data.resolvedBy);
    if (data.closedBy) userIds.push(data.closedBy);
  });

  const users = await batchLoadUsers(userIds);

  return tickets.map((ticket) => {
    const data = ticket.toJSON ? ticket.toJSON() : { ...ticket };
    const customer = data.userId ? users.get(data.userId) : null;
    if (customer) {
      data.userEmail = customer.email;
      data.userName = customer.name;
    }
    const assignee = data.assignedTo ? users.get(data.assignedTo) : null;
    if (assignee) {
      data.assignedToName = assignee.name;
    }
    const escalator = data.escalatedBy ? users.get(data.escalatedBy) : null;
    if (escalator) {
      data.escalatedByName = escalator.name;
    }
    return mapTicketForClient(data);
  });
}

function mapMessagesToComments(messages) {
  if (!Array.isArray(messages)) return [];
  return messages.map((msg) => ({
    objectId: msg.objectId,
    content: msg.message || msg.content || '',
    isInternal: !!msg.isInternal,
    createdBy: msg.senderId || msg.createdBy,
    createdByName: msg.senderName || msg.createdByName,
    createdAt: msg.createdAt,
  }));
}

function mapTicketForClient(ticketData) {
  const mapped = { ...ticketData };
  mapped.status = normalizeStatusForClient(mapped.status);
  if (mapped.messages) {
    mapped.comments = mapMessagesToComments(mapped.messages);
  }
  return mapped;
}

async function listTickets(params = {}, sortOptions) {
  const { applyQuerySort } = require('./applyQuerySort');
  const Ticket = Parse.Object.extend('SupportTicket');
  const {
    limit = 50,
    skip = 0,
  } = params;

  const safeLimit = Math.min(Math.max(1, limit), MAX_LIST_LIMIT);
  const filters = { ...params };

  const countQuery = buildListQuery(Ticket, filters);
  const total = await countQuery.count({ useMasterKey: true });

  const pageQuery = buildListQuery(Ticket, filters);
  applyQuerySort(pageQuery, params, sortOptions || {
    allowed: ['createdAt', 'updatedAt', 'priority'],
    defaultField: 'createdAt',
    defaultDesc: true,
  });
  pageQuery.skip(skip);
  pageQuery.limit(safeLimit);

  const tickets = await pageQuery.find({ useMasterKey: true });
  const enrichedTickets = await enrichTicketsBatch(tickets);

  return { tickets: enrichedTickets, total };
}

async function getTicketDetail(ticketId) {
  const Ticket = Parse.Object.extend('SupportTicket');
  const ticket = await new Parse.Query(Ticket).get(ticketId, { useMasterKey: true });
  const ticketData = ticket.toJSON();

  const Message = Parse.Object.extend('TicketMessage');
  const msgQuery = new Parse.Query(Message);
  msgQuery.equalTo('ticketId', ticketId);
  msgQuery.ascending('createdAt');
  const messages = await msgQuery.find({ useMasterKey: true });
  ticketData.messages = messages.map((m) => m.toJSON());

  const [enriched] = await enrichTicketsBatch([ticketData]);
  return enriched;
}

async function logTicketAudit({
  actorId,
  actorRole,
  ticketId,
  action,
  oldValues = {},
  newValues = {},
  metadata = {},
}) {
  try {
    const AuditLog = Parse.Object.extend('AuditLog');
    const log = new AuditLog();
    log.set('logType', 'action');
    log.set('action', action);
    log.set('userId', actorId);
    log.set('userRole', actorRole);
    log.set('resourceType', 'SupportTicket');
    log.set('resourceId', ticketId);
    log.set('oldValues', oldValues);
    log.set('newValues', newValues);
    log.set('metadata', metadata);
    await log.save(null, { useMasterKey: true });
  } catch (error) {
    console.error('Failed to log ticket audit:', error.message);
  }
}

async function logTicketComplianceEvent({
  customerUserId,
  eventType,
  severity,
  description,
  metadata = {},
  requiresReview = false,
}) {
  if (!customerUserId) return;
  try {
    const ComplianceEvent = Parse.Object.extend('ComplianceEvent');
    const event = new ComplianceEvent();
    event.set('userId', customerUserId);
    event.set('eventType', eventType);
    event.set('severity', severity);
    event.set('description', description);
    event.set('metadata', metadata);
    event.set('occurredAt', new Date());
    if (requiresReview) {
      event.set('requiresReview', true);
    }
    await event.save(null, { useMasterKey: true });
  } catch (error) {
    console.error('Failed to log ticket compliance event:', error.message);
  }
}

function validateStatusTransition(oldStatus, newStatus) {
  const oldCanonical = normalizeStatusForStorage(oldStatus);
  const newCanonical = normalizeStatusForStorage(newStatus);
  if (oldCanonical === newCanonical) return;

  const terminal = new Set(ARCHIVE_STATUSES);
  if (terminal.has(oldCanonical) && !['open', 'archived'].includes(newCanonical)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Cannot transition ticket from ${oldCanonical} to ${newCanonical}`,
    );
  }
}

function isTicketAlreadyEscalated(ticket) {
  return ticket.get('escalated') === true || ticket.get('status') === 'escalated';
}

/**
 * Shared escalation path (manual CSR or SLA auto-job).
 * @returns {{ skipped?: boolean, ticketId: string }}
 */
async function escalateTicketRecord({
  ticket,
  ticketId,
  reason,
  actorId = 'system',
  actorRole = 'system',
  isAutomatic = false,
}) {
  const Ticket = Parse.Object.extend('SupportTicket');
  const record = ticket
    || await new Parse.Query(Ticket).get(ticketId, { useMasterKey: true });

  if (isTicketAlreadyEscalated(record)) {
    return { skipped: true, ticketId: record.id };
  }

  const oldStatus = record.get('status');
  validateStatusTransition(oldStatus, 'escalated');

  const trimmedReason = String(reason || '').trim();
  if (!trimmedReason) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'escalation reason required');
  }

  record.set('escalated', true);
  record.set('status', 'escalated');
  record.set('escalationReason', trimmedReason);
  record.set('escalatedAt', new Date());
  record.set('escalatedBy', actorId);
  if (isAutomatic) {
    record.set('slaAutoEscalated', true);
  }
  await record.save(null, { useMasterKey: true });

  const customerUserId = record.get('userId');
  const ticketNumber = record.get('ticketNumber') || record.id;

  await logTicketAudit({
    actorId,
    actorRole,
    ticketId: record.id,
    action: isAutomatic ? 'ticket_escalated_sla_auto' : 'ticket_escalated',
    oldValues: { status: oldStatus },
    newValues: { status: 'escalated', escalationReason: trimmedReason, isAutomatic },
  });

  await logTicketComplianceEvent({
    customerUserId,
    eventType: 'escalation',
    severity: 'high',
    description: isAutomatic
      ? `Automatische Eskalation: Ticket ${ticketNumber} - ${trimmedReason}`
      : `Support-Ticket ${ticketNumber} eskaliert: ${trimmedReason}`,
    metadata: { ticketId: record.id, ticketNumber, escalatedBy: actorId, isAutomatic },
    requiresReview: true,
  });

  const result = { skipped: false, ticketId: record.id, ticketNumber };

  const { scheduleTicketEscalated } = require('./ticketEmailNotifier');
  scheduleTicketEscalated(record, trimmedReason);

  return result;
}

async function addInternalTicketNote(ticketId, message, senderId, senderName) {
  const Message = Parse.Object.extend('TicketMessage');
  const msg = new Message();
  msg.set('ticketId', ticketId);
  msg.set('message', message);
  msg.set('senderId', senderId || 'system');
  msg.set('senderName', senderName || 'System');
  msg.set('isInternal', true);
  await msg.save(null, { useMasterKey: true });
  return msg;
}

async function notifyAgentSlaViolation({ agentId, ticketNumber, ticketId, violationReason }) {
  if (!agentId) return;
  try {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', agentId);
    notif.set('type', 'sla_violation');
    notif.set('category', 'support');
    notif.set('title', `SLA-Verletzung: Ticket ${ticketNumber}`);
    notif.set('message', `Das Ticket wurde automatisch eskaliert. ${violationReason}`);
    notif.set('priority', 'high');
    notif.set('referenceType', 'ticket');
    notif.set('referenceId', ticketId);
    notif.set('isRead', false);
    notif.set('channels', ['in_app']);
    await notif.save(null, { useMasterKey: true });
  } catch (error) {
    console.error('Failed to send SLA violation notification:', error.message);
  }
}

module.exports = {
  ACTIVE_STATUSES,
  ARCHIVE_STATUSES,
  CANONICAL_STATUSES,
  MAX_LIST_LIMIT,
  normalizeStatusForStorage,
  normalizeStatusForClient,
  isValidStatus,
  assertValidStatus,
  validateStatusTransition,
  buildListQuery,
  enrichTicketsBatch,
  mapMessagesToComments,
  mapTicketForClient,
  listTickets,
  getTicketDetail,
  logTicketAudit,
  logTicketComplianceEvent,
  isTicketAlreadyEscalated,
  escalateTicketRecord,
  addInternalTicketNote,
  notifyAgentSlaViolation,
};
