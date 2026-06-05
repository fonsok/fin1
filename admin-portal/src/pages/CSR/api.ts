import { cloudFunction } from '../../api/admin';
import { getTickets, type TicketListParams } from '../../api/admin/tickets';
import type {
  CustomerSearchResult,
  CustomerProfile,
  CustomerInvestmentSummary,
  CustomerTradeSummary,
  CustomerDocumentSummary,
  CustomerKYCStatus,
  SupportTicket,
  CSRAgent,
  TicketMetrics,
  AgentMetrics,
} from './types';

// Customer Search
export async function searchCustomers(query: string): Promise<CustomerSearchResult[]> {
  const result = await cloudFunction<{ results: CustomerSearchResult[] }>('searchCustomers', { query });
  return result.results || [];
}

/** @param userId Parse _User.objectId */
export async function getCustomerProfile(userId: string): Promise<CustomerProfile | null> {
  return cloudFunction<CustomerProfile | null>('getCustomerProfile', { userId });
}

export async function getCustomerInvestments(userId: string): Promise<CustomerInvestmentSummary[]> {
  const result = await cloudFunction<{ investments: CustomerInvestmentSummary[] }>('getCustomerInvestments', { userId });
  return result.investments || [];
}

export async function getCustomerTrades(userId: string): Promise<CustomerTradeSummary[]> {
  const result = await cloudFunction<{ trades: CustomerTradeSummary[] }>('getCustomerTrades', { userId });
  return result.trades || [];
}

export async function getCustomerDocuments(userId: string): Promise<CustomerDocumentSummary[]> {
  const result = await cloudFunction<{ documents: CustomerDocumentSummary[] }>('getCustomerDocuments', { userId });
  return result.documents || [];
}

export async function getCustomerKYCStatus(userId: string): Promise<CustomerKYCStatus | null> {
  return cloudFunction<CustomerKYCStatus | null>('getCustomerKYCStatus', { userId });
}

/** Paginated ticket list — preferred over legacy getSupportTickets. */
export async function listSupportTickets(
  params: TicketListParams = {},
): Promise<{ tickets: SupportTicket[]; total: number }> {
  const result = await getTickets(params);
  return {
    tickets: result.tickets as unknown as SupportTicket[],
    total: result.total,
  };
}

/** @deprecated Use listSupportTickets — returns tickets only (no total). */
export async function getSupportTickets(userId?: string): Promise<SupportTicket[]> {
  const { tickets } = await listSupportTickets({
    userId: userId || undefined,
    limit: 50,
  });
  return tickets;
}

export async function getTicket(ticketId: string): Promise<SupportTicket | null> {
  return cloudFunction<SupportTicket | null>('getTicket', { ticketId });
}

export async function createSupportTicket(ticket: {
  userId: string;
  subject: string;
  description: string;
  category: string;
  priority?: string;
}): Promise<SupportTicket> {
  return cloudFunction<SupportTicket>('createSupportTicket', ticket);
}

export async function respondToTicket(
  ticketId: string,
  response: string,
  isInternal: boolean = false
): Promise<void> {
  await cloudFunction('respondToTicket', { ticketId, response, isInternal });
}

export async function assignTicket(ticketId: string, agentId: string): Promise<void> {
  await cloudFunction('assignTicket', { ticketId, agentId });
}

export async function escalateTicket(ticketId: string, reason: string): Promise<void> {
  await cloudFunction('escalateTicket', { ticketId, reason });
}

export async function resolveTicket(
  ticketId: string,
  resolutionNote: string,
  customerConfirmed: boolean = false
): Promise<void> {
  await cloudFunction('resolveTicket', { ticketId, resolutionNote, customerConfirmed });
}

export async function closeTicket(ticketId: string, closureReason: string): Promise<void> {
  await cloudFunction('closeTicket', { ticketId, closureReason });
}

// Agents
export async function getAvailableAgents(): Promise<CSRAgent[]> {
  const result = await cloudFunction<{ agents: CSRAgent[] }>('getAvailableAgents', {});
  return result.agents || [];
}

// Analytics
export interface SupportTrend {
  id: string;
  type: string;
  title: string;
  description: string;
  severity: 'info' | 'warning' | 'critical';
  ticketCount: number;
  affectedCustomers: number;
  percentageChange: number;
  detectedAt: string;
  relatedTicketIds: string[];
  suggestedAction: string;
}

export async function getSupportTrends(weeksBack = 2): Promise<{
  trends: SupportTrend[];
  meta: { currentWeekCount: number; previousWeekCount: number; ticketsAnalyzed: number; truncated?: boolean };
}> {
  const result = await cloudFunction<{
    trends: SupportTrend[];
    meta: { currentWeekCount: number; previousWeekCount: number; ticketsAnalyzed: number; truncated?: boolean };
  }>('getSupportTrends', { weeksBack });
  return { trends: result.trends || [], meta: result.meta };
}

export async function getTicketMetrics(from: Date, to: Date): Promise<TicketMetrics> {
  return cloudFunction<TicketMetrics>('getTicketMetrics', {
    fromDate: from.toISOString(),
    toDate: to.toISOString(),
  });
}

export async function getAgentMetrics(
  agentId: string,
  from: Date,
  to: Date
): Promise<AgentMetrics> {
  return cloudFunction<AgentMetrics>('getAgentMetrics', {
    agentId,
    fromDate: from.toISOString(),
    toDate: to.toISOString(),
  });
}
