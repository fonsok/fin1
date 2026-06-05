'use strict';

const TICKET_TREND_FIELDS = ['category', 'userId', 'status', 'createdAt', 'escalated', 'priority'];
const LEAN_PAGE_SIZE = 500;
const MAX_LEAN_ROWS = 5000;

async function countTicketsBetween(from, to) {
  const q = new Parse.Query('SupportTicket');
  q.greaterThanOrEqualTo('createdAt', from);
  if (to) {
    q.lessThan('createdAt', to);
  }
  return q.count({ useMasterKey: true });
}

/**
 * Load minimal ticket rows for trend detection (paginated, field-select).
 */
async function fetchTicketsLeanSince(since, maxRows = MAX_LEAN_ROWS) {
  const rows = [];
  let skip = 0;

  while (rows.length < maxRows) {
    const q = new Parse.Query('SupportTicket');
    q.greaterThanOrEqualTo('createdAt', since);
    q.select(TICKET_TREND_FIELDS);
    q.ascending('createdAt');
    q.skip(skip);
    q.limit(LEAN_PAGE_SIZE);

    const page = await q.find({ useMasterKey: true });
    if (!page.length) break;

    page.forEach((t) => {
      rows.push({
        objectId: t.id,
        userId: t.get('userId'),
        category: t.get('category') || 'Other',
        status: t.get('status'),
        createdAt: t.get('createdAt'),
        escalated: t.get('escalated') === true,
        priority: t.get('priority'),
      });
    });

    if (page.length < LEAN_PAGE_SIZE) break;
    skip += LEAN_PAGE_SIZE;
  }

  return rows;
}

function isEscalatedTicket(ticket) {
  return ticket.escalated === true || ticket.status === 'escalated';
}

/**
 * Trend detection (parity with CSR Trends page).
 * @param {Array<object>} tickets lean ticket rows
 */
function detectSupportTrends(tickets) {
  if (!tickets.length) return [];

  const trends = [];
  const now = new Date();
  const lastWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const previousWeek = new Date(lastWeek.getTime() - 7 * 24 * 60 * 60 * 1000);

  const currentWeekTickets = tickets.filter((t) => new Date(t.createdAt) >= lastWeek);
  const previousWeekTickets = tickets.filter(
    (t) => new Date(t.createdAt) >= previousWeek && new Date(t.createdAt) < lastWeek,
  );

  if (currentWeekTickets.length > 0 && previousWeekTickets.length > 0) {
    const percentageChange =
      ((currentWeekTickets.length - previousWeekTickets.length) / previousWeekTickets.length) * 100;
    if (percentageChange >= 50) {
      trends.push({
        id: 'volume-spike',
        type: 'volumeSpike',
        title: `Ticket-Volumen um ${Math.round(percentageChange)}% gestiegen`,
        description: `${currentWeekTickets.length} Tickets diese Woche (zuvor: ${previousWeekTickets.length})`,
        severity: percentageChange > 100 ? 'critical' : 'warning',
        ticketCount: currentWeekTickets.length,
        affectedCustomers: new Set(currentWeekTickets.map((t) => t.userId)).size,
        percentageChange,
        detectedAt: now.toISOString(),
        relatedTicketIds: currentWeekTickets.slice(0, 10).map((t) => t.objectId),
        suggestedAction:
          'Überprüfen Sie die häufigsten Ticket-Themen und erwägen Sie zusätzliche Ressourcen.',
      });
    }
  }

  const categoryCounts = {};
  currentWeekTickets.forEach((ticket) => {
    const category = ticket.category || 'Other';
    categoryCounts[category] = (categoryCounts[category] || 0) + 1;
  });

  Object.entries(categoryCounts).forEach(([category, count]) => {
    if (count >= 5) {
      const relatedTickets = currentWeekTickets.filter((t) => (t.category || 'Other') === category);
      trends.push({
        id: `recurring-${category}`,
        type: 'recurringIssue',
        title: `${count} Tickets zu "${category}"`,
        description:
          'Wiederkehrendes Problem erkannt. Möglicherweise ist eine technische Lösung erforderlich.',
        severity: count >= 10 ? 'critical' : 'warning',
        ticketCount: count,
        affectedCustomers: new Set(relatedTickets.map((t) => t.userId)).size,
        percentageChange: 0,
        detectedAt: now.toISOString(),
        relatedTicketIds: relatedTickets.slice(0, 10).map((t) => t.objectId),
        suggestedAction:
          'Prüfen Sie ob ein Produktfehler vorliegt oder die Dokumentation verbessert werden kann.',
      });
    }
  });

  const unresolvedTickets = currentWeekTickets.filter(
    (t) => t.status !== 'resolved' && t.status !== 'closed' && t.status !== 'archived',
  );
  const oldTickets = unresolvedTickets.filter((t) => {
    const hoursOld = (now.getTime() - new Date(t.createdAt).getTime()) / (1000 * 60 * 60);
    return hoursOld > 48;
  });

  if (oldTickets.length > 0) {
    trends.push({
      id: 'long-resolution',
      type: 'longResolutionTime',
      title: `${oldTickets.length} Tickets älter als 48 Stunden`,
      description: 'Diese Tickets benötigen dringend Aufmerksamkeit.',
      severity: oldTickets.length >= 10 ? 'critical' : 'warning',
      ticketCount: oldTickets.length,
      affectedCustomers: new Set(oldTickets.map((t) => t.userId)).size,
      percentageChange: 0,
      detectedAt: now.toISOString(),
      relatedTicketIds: oldTickets.slice(0, 10).map((t) => t.objectId),
      suggestedAction: 'Priorisieren Sie diese Tickets und weisen Sie sie erfahrenen Agents zu.',
    });
  }

  const escalatedTickets = currentWeekTickets.filter(isEscalatedTicket);
  const escalationRate = currentWeekTickets.length
    ? (escalatedTickets.length / currentWeekTickets.length) * 100
    : 0;
  if (escalationRate >= 20 && currentWeekTickets.length > 0) {
    trends.push({
      id: 'high-escalation',
      type: 'highEscalationRate',
      title: `Hohe Eskalationsrate: ${Math.round(escalationRate)}%`,
      description: `${escalatedTickets.length} von ${currentWeekTickets.length} Tickets sind eskaliert`,
      severity: escalationRate >= 30 ? 'critical' : 'warning',
      ticketCount: escalatedTickets.length,
      affectedCustomers: new Set(escalatedTickets.map((t) => t.userId)).size,
      percentageChange: escalationRate,
      detectedAt: now.toISOString(),
      relatedTicketIds: escalatedTickets.slice(0, 10).map((t) => t.objectId),
      suggestedAction: 'Analysieren Sie die Ursachen für die hohe Eskalationsrate.',
    });
  }

  return trends;
}

/**
 * Count-accurate volume spike when lean fetch is truncated.
 */
function appendVolumeSpikeFromCounts(trends, currentWeekCount, previousWeekCount) {
  if (!currentWeekCount || !previousWeekCount) return trends;
  const percentageChange = ((currentWeekCount - previousWeekCount) / previousWeekCount) * 100;
  if (percentageChange < 50) return trends;
  if (trends.some((t) => t.id === 'volume-spike')) return trends;

  return [
    {
      id: 'volume-spike',
      type: 'volumeSpike',
      title: `Ticket-Volumen um ${Math.round(percentageChange)}% gestiegen`,
      description: `${currentWeekCount} Tickets diese Woche (zuvor: ${previousWeekCount})`,
      severity: percentageChange > 100 ? 'critical' : 'warning',
      ticketCount: currentWeekCount,
      affectedCustomers: 0,
      percentageChange,
      detectedAt: new Date().toISOString(),
      relatedTicketIds: [],
      suggestedAction:
        'Überprüfen Sie die häufigsten Ticket-Themen und erwägen Sie zusätzliche Ressourcen.',
    },
    ...trends,
  ];
}

async function computeSupportTrends({ weeksBack = 2 } = {}) {
  const now = new Date();
  const lastWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const previousWeek = new Date(lastWeek.getTime() - 7 * 24 * 60 * 60 * 1000);
  const fetchSince = new Date(
    previousWeek.getTime() - Math.max(0, weeksBack - 2) * 7 * 24 * 60 * 60 * 1000,
  );

  const [currentWeekCount, previousWeekCount, tickets] = await Promise.all([
    countTicketsBetween(lastWeek, null),
    countTicketsBetween(previousWeek, lastWeek),
    fetchTicketsLeanSince(fetchSince),
  ]);

  let trends = detectSupportTrends(tickets);
  trends = appendVolumeSpikeFromCounts(trends, currentWeekCount, previousWeekCount);

  return {
    trends,
    meta: {
      currentWeekCount,
      previousWeekCount,
      ticketsAnalyzed: tickets.length,
      truncated: tickets.length >= MAX_LEAN_ROWS,
      generatedAt: now.toISOString(),
    },
  };
}

module.exports = {
  detectSupportTrends,
  computeSupportTrends,
  isEscalatedTicket,
};
