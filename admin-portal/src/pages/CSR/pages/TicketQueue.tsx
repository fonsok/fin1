import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Card, Button, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { getSupportTickets, assignTicket, getAvailableAgents } from '../api';

export function TicketQueuePage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [selectedTicketId, setSelectedTicketId] = useState<string | null>(null);
  const [selectedAgentId, setSelectedAgentId] = useState('');

  const { data: tickets, isLoading } = useQuery({
    queryKey: ['csr-tickets-queue'],
    queryFn: () => getSupportTickets(),
  });

  const { data: agents } = useQuery({
    queryKey: ['csr-agents'],
    queryFn: () => getAvailableAgents(),
  });

  const assignMutation = useMutation({
    mutationFn: ({ ticketId, agentId }: { ticketId: string; agentId: string }) =>
      assignTicket(ticketId, agentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['csr-tickets-queue'] });
      setSelectedTicketId(null);
      setSelectedAgentId('');
    },
  });

  const unassignedTickets = (tickets || []).filter(
    (t) => !t.assignedTo && t.status !== 'resolved' && t.status !== 'closed' && t.status !== 'archived'
  );

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

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Ticket-Warteschlange</h1>
        <Badge variant="warning">{unassignedTickets.length} unzugewiesen</Badge>
      </div>

      <Card>
        {unassignedTickets.length === 0 ? (
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
            <p className="text-gray-500">Keine unzugewiesenen Tickets</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Ticket
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Betreff
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Priorität
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Kunde
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Erstellt
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Aktionen
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {unassignedTickets.map((ticket) => (
                  <tr key={ticket.objectId} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-mono text-fin1-primary">
                        #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <button
                        onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                        className="text-sm text-gray-900 hover:text-fin1-primary hover:underline"
                      >
                        {ticket.subject}
                      </button>
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
                      {formatDateTime(ticket.createdAt)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex gap-2">
                        <select
                          value={selectedTicketId === ticket.objectId ? selectedAgentId : ''}
                          onChange={(e) => {
                            setSelectedTicketId(ticket.objectId);
                            setSelectedAgentId(e.target.value);
                            if (e.target.value) {
                              assignMutation.mutate({
                                ticketId: ticket.objectId,
                                agentId: e.target.value,
                              });
                            }
                          }}
                          className="text-sm border rounded px-2 py-1"
                          disabled={assignMutation.isPending}
                        >
                          <option value="">Zuweisen...</option>
                          {agents?.map((agent) => (
                            <option key={agent.objectId} value={agent.objectId}>
                              {agent.firstName} {agent.lastName}
                            </option>
                          ))}
                        </select>
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                        >
                          Öffnen
                        </Button>
                      </div>
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
