import { cloudFunction } from '../parse';
import type { Ticket } from './types';

export interface TicketListParams {
  status?: string;
  priority?: string;
  category?: string;
  assignedTo?: string;
  userId?: string;
  unassigned?: boolean;
  activeOnly?: boolean;
  archiveOnly?: boolean;
  fromDate?: string;
  toDate?: string;
  limit?: number;
  skip?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

/** Paginated ticket list (Admin + CSR). */
export async function getTickets(
  params: TicketListParams = {},
): Promise<{ tickets: Ticket[]; total: number }> {
  return cloudFunction('getTickets', params as Record<string, unknown>);
}
