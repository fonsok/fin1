import { useQuery } from '@tanstack/react-query';
import { getTickets, type TicketListParams } from '../api/admin/tickets';

export const ticketListKeys = {
  all: ['tickets'] as const,
  list: (params: TicketListParams) => ['tickets', params] as const,
};

const DEFAULT_STALE_MS = 30_000;

export function useTicketList(params: TicketListParams, options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: ticketListKeys.list(params),
    queryFn: () => getTickets(params),
    staleTime: DEFAULT_STALE_MS,
    enabled: options?.enabled !== false,
  });
}
