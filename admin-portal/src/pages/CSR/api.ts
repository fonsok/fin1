import { cloudFunction } from '../../api/admin';
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

export async function getSupportTickets(userId?: string): Promise<SupportTicket[]> {
  const result = await cloudFunction<{ tickets: SupportTicket[] }>('getSupportTickets', {
    userId: userId || undefined,
  });
  return result.tickets || [];
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
