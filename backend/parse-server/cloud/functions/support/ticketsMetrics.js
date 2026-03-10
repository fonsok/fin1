'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

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
 * Get ticket metrics
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
  openQuery.containedIn('status', ['open', 'in_progress', 'waiting']);
  const openTickets = await openQuery.count({ useMasterKey: true });

  const resolvedQuery = new Parse.Query('SupportTicket');
  resolvedQuery.containedIn('status', ['resolved', 'closed']);
  resolvedQuery.greaterThanOrEqualTo('resolvedAt', from);
  const resolvedTickets = await resolvedQuery.count({ useMasterKey: true });

  return {
    totalTickets: total,
    openTickets,
    resolvedTickets,
    averageResolutionTime: 0, // Would need more complex calculation
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
  const ticketsAssigned = await assignedQuery.count({ useMasterKey: true });

  const resolvedQuery = new Parse.Query('SupportTicket');
  resolvedQuery.equalTo('resolvedBy', agentId);
  resolvedQuery.greaterThanOrEqualTo('resolvedAt', from);
  const ticketsResolved = await resolvedQuery.count({ useMasterKey: true });

  // Get agent info
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

