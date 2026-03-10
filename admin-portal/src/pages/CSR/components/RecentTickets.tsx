import { Card, Badge, getStatusVariant } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import type { SupportTicket } from '../types';
import { useNavigate } from 'react-router-dom';

interface RecentTicketsProps {
  tickets: SupportTicket[];
  isLoading: boolean;
}

export function RecentTickets({ tickets, isLoading }: RecentTicketsProps) {
  const navigate = useNavigate();

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
      case 'open': return 'Offen';
      case 'in_progress': return 'In Bearbeitung';
      case 'waiting': return 'Wartend';
      case 'resolved': return 'Gelöst';
      case 'closed': return 'Geschlossen';
      default: return status || '-';
    }
  };

  if (isLoading) {
    return (
      <Card>
        <div className="text-center py-8">
          <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          <p className="text-gray-500 mt-4">Laden...</p>
        </div>
      </Card>
    );
  }

  if (tickets.length === 0) {
    return (
      <Card>
        <div className="text-center py-8">
          <svg
            className="w-12 h-12 text-gray-300 mx-auto mb-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <p className="text-gray-500">Keine aktiven Tickets</p>
          <p className="text-sm text-gray-400 mt-2">Alle Tickets wurden bearbeitet</p>
        </div>
      </Card>
    );
  }

  return (
    <Card>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold">Aktuelle Tickets</h2>
        <button
          onClick={() => navigate('/csr/tickets')}
          className="text-sm text-fin1-primary hover:underline"
        >
          Alle anzeigen
        </button>
      </div>
      <div className="space-y-2">
        {tickets.map((ticket) => (
          <div
            key={ticket.objectId}
            onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
            className="p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
          >
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-sm font-mono text-fin1-primary">
                    #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                  </span>
                  <span className="text-sm font-medium text-gray-900">{ticket.subject}</span>
                </div>
                {ticket.userEmail && (
                  <div className="text-xs text-gray-500">{ticket.userEmail}</div>
                )}
              </div>
              <div className="flex items-center gap-2">
                <Badge variant={getStatusVariant(ticket.status)}>
                  {getTicketStatusLabel(ticket.status)}
                </Badge>
                <Badge variant={getPriorityVariant(ticket.priority)}>
                  {getPriorityLabel(ticket.priority)}
                </Badge>
                <div className="text-xs text-gray-500">{formatDateTime(ticket.createdAt)}</div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}
