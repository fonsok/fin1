'use strict';

const { requireAdminRole } = require('../../utils/permissions');
const { ACTIVE_STATUSES } = require('../../utils/supportTicketHelper');

// ============================================================================
// CSR PORTAL - AGENTS & METRICS
// ============================================================================

/**
 * Get available CSR agents
 */
Parse.Cloud.define('getAvailableAgents', async (request) => {
  requireAdminRole(request);

  const query = new Parse.Query(Parse.User);
  query.equalTo('role', 'customer_service');
  query.limit(100);

  const agents = await query.find({ useMasterKey: true });

  return {
    agents: agents.map((agent) => ({
      objectId: agent.id,
      email: agent.get('email'),
      firstName: agent.get('firstName'),
      lastName: agent.get('lastName'),
      csrSubRole: agent.get('csrSubRole'),
      status: agent.get('status') || 'active',
    })),
  };
});

/**
 * Get ticket metrics (count-based, no full ticket load)
 */
Parse.Cloud.define('getTicketMetrics', async (request) => {
  requireAdminRole(request);

  const { fromDate, toDate } = request.params;

  const from = fromDate ? new Date(fromDate) : new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const to = toDate ? new Date(toDate) : new Date();

  const baseQuery = new Parse.Query('SupportTicket');
  baseQuery.greaterThanOrEqualTo('createdAt', from);
  baseQuery.lessThanOrEqualTo('createdAt', to);
  const total = await baseQuery.count({ useMasterKey: true });

  const openQuery = new Parse.Query('SupportTicket');
  openQuery.containedIn('status', ACTIVE_STATUSES);
  const openTickets = await openQuery.count({ useMasterKey: true });

  const escalatedStatusQuery = new Parse.Query('SupportTicket');
  escalatedStatusQuery.equalTo('status', 'escalated');
  const escalatedFlagQuery = new Parse.Query('SupportTicket');
  escalatedFlagQuery.equalTo('escalated', true);
  const escalatedOr = Parse.Query.or(escalatedStatusQuery, escalatedFlagQuery);
  const escalatedTickets = await escalatedOr.count({ useMasterKey: true });

  const resolvedQuery = new Parse.Query('SupportTicket');
  resolvedQuery.containedIn('status', ['resolved', 'closed']);
  resolvedQuery.greaterThanOrEqualTo('resolvedAt', from);
  resolvedQuery.lessThanOrEqualTo('resolvedAt', to);
  const resolvedTickets = await resolvedQuery.count({ useMasterKey: true });

  const durationQuery = new Parse.Query('SupportTicket');
  durationQuery.containedIn('status', ['resolved', 'closed']);
  durationQuery.greaterThanOrEqualTo('resolvedAt', from);
  durationQuery.lessThanOrEqualTo('resolvedAt', to);
  durationQuery.exists('resolvedAt');
  durationQuery.limit(200);
  const resolvedWithDuration = await durationQuery.find({ useMasterKey: true });
  let averageResolutionTime = 0;
  const durations = resolvedWithDuration
    .map((t) => {
      const resolvedAt = t.get('resolvedAt');
      const createdAt = t.get('createdAt');
      if (!resolvedAt || !createdAt) return null;
      return (resolvedAt.getTime() - createdAt.getTime()) / (1000 * 60 * 60);
    })
    .filter((h) => h != null && h >= 0);
  if (durations.length > 0) {
    averageResolutionTime = durations.reduce((a, b) => a + b, 0) / durations.length;
  }

  return {
    totalTickets: total,
    openTickets,
    escalatedTickets,
    resolvedTickets,
    averageResolutionTime: Math.round(averageResolutionTime * 10) / 10,
    averageResponseTime: 0,
  };
});

/**
 * Get agent metrics
 */
Parse.Cloud.define('getAgentMetrics', async (request) => {
  requireAdminRole(request);

  const { agentId, fromDate, toDate } = request.params;

  if (!agentId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'agentId required');
  }

  const from = fromDate ? new Date(fromDate) : new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const to = toDate ? new Date(toDate) : new Date();

  const assignedQuery = new Parse.Query('SupportTicket');
  assignedQuery.equalTo('assignedTo', agentId);
  assignedQuery.greaterThanOrEqualTo('createdAt', from);
  assignedQuery.lessThanOrEqualTo('createdAt', to);
  const ticketsAssigned = await assignedQuery.count({ useMasterKey: true });

  const resolvedQuery = new Parse.Query('SupportTicket');
  resolvedQuery.equalTo('resolvedBy', agentId);
  resolvedQuery.greaterThanOrEqualTo('resolvedAt', from);
  resolvedQuery.lessThanOrEqualTo('resolvedAt', to);
  const ticketsResolved = await resolvedQuery.count({ useMasterKey: true });

  const agentQuery = new Parse.Query(Parse.User);
  const agent = await agentQuery.get(agentId, { useMasterKey: true });

  return {
    agentId,
    agentName: `${agent.get('firstName') || ''} ${agent.get('lastName') || ''}`.trim(),
    ticketsAssigned,
    ticketsResolved,
    averageResolutionTime: 0,
    customerSatisfaction: 0,
  };
});
