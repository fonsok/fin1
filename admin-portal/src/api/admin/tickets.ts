import { cloudFunction } from '../parse';
import type { Ticket } from './types';

/** Get tickets */
export async function getTickets(params: {
  status?: string;
  priority?: string;
  assignedTo?: string;
  limit?: number;
  skip?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}): Promise<{ tickets: Ticket[]; total: number }> {
  return cloudFunction('getTickets', params);
}
