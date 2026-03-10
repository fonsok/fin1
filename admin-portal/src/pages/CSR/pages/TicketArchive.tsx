import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Card, Badge, getStatusVariant } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { getSupportTickets } from '../api';

export function TicketArchivePage() {
  const navigate = useNavigate();
  const [statusFilter, setStatusFilter] = useState<'resolved' | 'closed' | 'all'>('all');

  const { data: tickets, isLoading } = useQuery({
    queryKey: ['csr-tickets-archive', statusFilter],
    queryFn: () => getSupportTickets(),
  });

  const archivedTickets = (tickets || []).filter((t) => {
    if (statusFilter === 'all') {
      return t.status === 'resolved' || t.status === 'closed' || t.status === 'archived';
    }
    return t.status === statusFilter;
  });

  const getPriorityVariant = (priority: string): 'success' | 'warning' | 'danger' | 'info' | 'neutral' => {
    switch (priority?.toLowerCase()) {
      case 'urgent': return 'danger';
      case 'high': return 'danger';
      case 'medium': return 'warning';
      case 'low': return 'info';
      default: return 'neutral';
    }
  };

  const getPriorityLabel = (priority: string): string => {
    switch (priority?.toLowerCase()) {
      case 'urgent': return 'Dringend';
      case 'high': return 'Hoch';
      case 'medium': return 'Mittel';
      case 'low': return 'Niedrig';
      default: return priority || '-';
    }
  };

  const getTicketStatusLabel = (status: string): string => {
    switch (status?.toLowerCase()) {
      case 'resolved': return 'Gelöst';
      case 'closed': return 'Geschlossen';
      case 'archived': return 'Archiviert';
      default: return status || '-';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Ticket-Archiv</h1>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'resolved' | 'closed' | 'all')}
          className="px-4 py-2 border rounded-lg"
        >
          <option value="all">Alle</option>
          <option value="resolved">Gelöst</option>
          <option value="closed">Geschlossen</option>
        </select>
      </div>

      <Card>
        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        ) : archivedTickets.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-gray-500">Keine archivierten Tickets gefunden</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Ticket
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Betreff
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Priorität
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Kunde
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Geschlossen
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {archivedTickets.map((ticket) => (
                  <tr
                    key={ticket.objectId}
                    onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                    className="hover:bg-gray-50 cursor-pointer"
                  >
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-mono text-fin1-primary">
                        #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <p className="text-sm text-gray-900">{ticket.subject}</p>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Badge variant={getStatusVariant(ticket.status)}>
                        {getTicketStatusLabel(ticket.status)}
                      </Badge>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Badge variant={getPriorityVariant(ticket.priority)}>
                        {getPriorityLabel(ticket.priority)}
                      </Badge>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {ticket.userEmail || ticket.userId}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {ticket.closedAt ? formatDateTime(ticket.closedAt) : ticket.resolvedAt ? formatDateTime(ticket.resolvedAt) : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}
