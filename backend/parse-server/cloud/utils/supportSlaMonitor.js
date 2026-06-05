'use strict';

const {
  ACTIVE_STATUSES,
  ARCHIVE_STATUSES,
  escalateTicketRecord,
  addInternalTicketNote,
  notifyAgentSlaViolation,
  isTicketAlreadyEscalated,
} = require('./supportTicketHelper');

/** Hours — aligned with triggers/support.js and iOS SLAConfiguration.default */
const SLA_HOURS = {
  urgent: { first: 1, resolution: 4 },
  high: { first: 4, resolution: 24 },
  medium: { first: 8, resolution: 48 },
  low: { first: 24, resolution: 72 },
};

const MONITOR_STATUSES = ['open', 'in_progress'];
const PAUSED_STATUSES = new Set(['waiting', 'waiting_for_customer']);
const DEFAULT_BATCH_LIMIT = 150;

function isWaitingStatus(status) {
  return PAUSED_STATUSES.has(status);
}

function slaTargetsForPriority(priority, createdAt) {
  const targets = SLA_HOURS[priority] || SLA_HOURS.medium;
  const base = createdAt instanceof Date ? createdAt : new Date(createdAt);
  return {
    firstResponseTarget: new Date(base.getTime() + targets.first * 60 * 60 * 1000),
    resolutionTarget: new Date(base.getTime() + targets.resolution * 60 * 60 * 1000),
  };
}

function resolveSlaTargets(ticket, slaRecord) {
  if (slaRecord) {
    const first = slaRecord.get('firstResponseTarget');
    const resolution = slaRecord.get('resolutionTarget');
    if (first && resolution) {
      return { firstResponseTarget: first, resolutionTarget: resolution };
    }
  }
  return slaTargetsForPriority(ticket.get('priority'), ticket.get('createdAt'));
}

/**
 * Pure SLA breach evaluation (mirrors iOS SupportTicket.getSLAInfo breach rules).
 */
function evaluateSlaBreach({ status, now, firstResponseTarget, resolutionTarget, hasFirstResponse }) {
  if (isWaitingStatus(status)) {
    return { breached: false, firstBreached: false, resolutionBreached: false, paused: true };
  }

  const ts = now.getTime();
  let firstBreached = false;
  let resolutionBreached = false;

  if (!hasFirstResponse && firstResponseTarget && ts > firstResponseTarget.getTime()) {
    firstBreached = true;
  }

  if (!ARCHIVE_STATUSES.includes(status) && resolutionTarget && ts > resolutionTarget.getTime()) {
    resolutionBreached = true;
  }

  return {
    breached: firstBreached || resolutionBreached,
    firstBreached,
    resolutionBreached,
    paused: false,
  };
}

function buildViolationReason({ firstBreached, resolutionBreached }) {
  if (firstBreached && resolutionBreached) {
    return 'Erste Antwort und Lösung: SLA-Deadline überschritten';
  }
  if (firstBreached) {
    return 'Erste Antwort: SLA-Deadline überschritten';
  }
  return 'Lösung: SLA-Deadline überschritten';
}

async function loadSlaByTicketIds(ticketIds) {
  const map = new Map();
  if (!ticketIds.length) return map;

  const query = new Parse.Query('TicketSLATracking');
  query.containedIn('ticketId', ticketIds);
  query.limit(Math.min(ticketIds.length, 500));
  const rows = await query.find({ useMasterKey: true });
  rows.forEach((row) => map.set(row.get('ticketId'), row));
  return map;
}

/** Tickets with at least one public (non-internal) message from someone other than the customer. */
async function loadTicketsWithAgentResponse(ticketIds, ticketsById) {
  const responded = new Set();
  if (!ticketIds.length) return responded;

  const query = new Parse.Query('TicketMessage');
  query.containedIn('ticketId', ticketIds);
  query.equalTo('isInternal', false);
  query.limit(1000);
  const messages = await query.find({ useMasterKey: true });

  messages.forEach((msg) => {
    const ticketId = msg.get('ticketId');
    const ticket = ticketsById.get(ticketId);
    if (!ticket) return;
    const customerId = ticket.get('userId');
    if (msg.get('senderId') && msg.get('senderId') !== customerId) {
      responded.add(ticketId);
    }
  });
  return responded;
}

async function markSlaBreached(slaRecord) {
  if (!slaRecord) return;
  if (slaRecord.get('slaStatus') === 'breached') return;
  slaRecord.set('slaStatus', 'breached');
  slaRecord.set('breachedAt', new Date());
  await slaRecord.save(null, { useMasterKey: true });
}

/**
 * Scan active tickets and auto-escalate on SLA breach (production worker).
 */
async function processSlaAutoEscalations({ limit = DEFAULT_BATCH_LIMIT } = {}) {
  const enabled = process.env.SLA_MONITOR_ENABLED !== '0';
  if (!enabled) {
    return { processed: 0, escalated: 0, skipped: true, reason: 'disabled' };
  }

  const Ticket = Parse.Object.extend('SupportTicket');
  const query = new Parse.Query(Ticket);
  query.containedIn('status', MONITOR_STATUSES);
  query.ascending('createdAt');
  query.limit(Math.min(limit, 500));

  const tickets = await query.find({ useMasterKey: true });
  const candidates = tickets.filter((t) => !isTicketAlreadyEscalated(t));

  if (!candidates.length) {
    return { processed: 0, escalated: 0, scanned: tickets.length };
  }

  const ticketIds = candidates.map((t) => t.id);
  const ticketsById = new Map(candidates.map((t) => [t.id, t]));
  const slaByTicket = await loadSlaByTicketIds(ticketIds);
  const withAgentResponse = await loadTicketsWithAgentResponse(ticketIds, ticketsById);

  const now = new Date();
  let escalated = 0;

  for (const ticket of candidates) {
    const status = ticket.get('status');
    const slaRecord = slaByTicket.get(ticket.id);
    const hasFirstResponse = withAgentResponse.has(ticket.id)
      || !!slaRecord?.get('firstResponseActual');

    const targets = resolveSlaTargets(ticket, slaRecord);
    const evaluation = evaluateSlaBreach({
      status,
      now,
      firstResponseTarget: targets.firstResponseTarget,
      resolutionTarget: targets.resolutionTarget,
      hasFirstResponse,
    });

    if (!evaluation.breached) continue;

    const violationReason = buildViolationReason(evaluation);
    const ticketNumber = ticket.get('ticketNumber') || ticket.id;

    const result = await escalateTicketRecord({
      ticket,
      reason: violationReason,
      actorId: 'system',
      actorRole: 'system',
      isAutomatic: true,
    });

    if (result.skipped) continue;

    const note = `⚠️ Automatische Eskalation: ${violationReason}. `
      + 'Das Ticket wurde automatisch eskaliert, da die SLA-Deadline überschritten wurde.';
    await addInternalTicketNote(ticket.id, note, 'system', 'SLA Monitor');

    const assignedTo = ticket.get('assignedTo');
    if (assignedTo) {
      await notifyAgentSlaViolation({
        agentId: assignedTo,
        ticketNumber,
        ticketId: ticket.id,
        violationReason,
      });
    }

    await markSlaBreached(slaRecord);
    escalated += 1;
  }

  return {
    processed: candidates.length,
    escalated,
    scanned: tickets.length,
    timestamp: now.toISOString(),
  };
}

function getSlaMonitorIntervalMs() {
  const fromEnv = Number(process.env.SLA_MONITOR_INTERVAL_MS);
  if (Number.isFinite(fromEnv) && fromEnv >= 60_000) {
    return fromEnv;
  }
  return 300_000; // 5 min — matches iOS Configuration default
}

module.exports = {
  SLA_HOURS,
  evaluateSlaBreach,
  buildViolationReason,
  processSlaAutoEscalations,
  getSlaMonitorIntervalMs,
};
