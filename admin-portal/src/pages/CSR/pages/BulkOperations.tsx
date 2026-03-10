import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Card, Button, Badge, getStatusVariant } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { getSupportTickets, assignTicket, respondToTicket, getAvailableAgents } from '../api';

export function BulkOperationsPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [selectedTickets, setSelectedTickets] = useState<Set<string>>(new Set());
  const [bulkAction, setBulkAction] = useState<'assign' | 'respond' | 'none'>('none');
  const [selectedAgentId, setSelectedAgentId] = useState('');
  const [bulkResponse, setBulkResponse] = useState('');
  const [isInternal, setIsInternal] = useState(false);

  const { data: tickets, isLoading } = useQuery({
    queryKey: ['csr-tickets-bulk'],
    queryFn: () => getSupportTickets(),
  });

  const { data: agents } = useQuery({
    queryKey: ['csr-agents'],
    queryFn: () => getAvailableAgents(),
  });

  const activeTickets = (tickets || []).filter(
    t => t.status !== 'resolved' && t.status !== 'closed' && t.status !== 'archived'
  );

  const assignMutation = useMutation({
    mutationFn: async ({ ticketIds, agentId }: { ticketIds: string[]; agentId: string }) => {
      await Promise.all(ticketIds.map(id => assignTicket(id, agentId)));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['csr-tickets'] });
      setSelectedTickets(new Set());
      setBulkAction('none');
      setSelectedAgentId('');
    },
  });

  const respondMutation = useMutation({
    mutationFn: async ({ ticketIds, response, isInternal }: { ticketIds: string[]; response: string; isInternal: boolean }) => {
      await Promise.all(ticketIds.map(id => respondToTicket(id, response, isInternal)));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['csr-tickets'] });
      setSelectedTickets(new Set());
      setBulkAction('none');
      setBulkResponse('');
      setIsInternal(false);
    },
  });

  const toggleTicket = (ticketId: string) => {
    const newSelected = new Set(selectedTickets);
    if (newSelected.has(ticketId)) {
      newSelected.delete(ticketId);
    } else {
      newSelected.add(ticketId);
    }
    setSelectedTickets(newSelected);
  };

  const selectAll = () => {
    if (selectedTickets.size === activeTickets.length) {
      setSelectedTickets(new Set());
    } else {
      setSelectedTickets(new Set(activeTickets.map(t => t.objectId)));
    }
  };

  const handleBulkAssign = () => {
    if (selectedTickets.size > 0 && selectedAgentId) {
      assignMutation.mutate({
        ticketIds: Array.from(selectedTickets),
        agentId: selectedAgentId,
      });
    }
  };

  const handleBulkRespond = () => {
    if (selectedTickets.size > 0 && bulkResponse.trim()) {
      respondMutation.mutate({
        ticketIds: Array.from(selectedTickets),
        response: bulkResponse,
        isInternal,
      });
    }
  };

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

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Massenbearbeitung</h1>
        <Badge variant="info">{selectedTickets.size} ausgewählt</Badge>
      </div>

      {/* Bulk Actions */}
      {selectedTickets.size > 0 && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Massenaktionen</h2>
          <div className="flex flex-wrap gap-2 mb-4">
            <Button
              variant={bulkAction === 'assign' ? 'primary' : 'secondary'}
              onClick={() => setBulkAction(bulkAction === 'assign' ? 'none' : 'assign')}
            >
              Zuweisen
            </Button>
            <Button
              variant={bulkAction === 'respond' ? 'primary' : 'secondary'}
              onClick={() => setBulkAction(bulkAction === 'respond' ? 'none' : 'respond')}
            >
              Antwort hinzufügen
            </Button>
          </div>

          {bulkAction === 'assign' && (
            <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
              <div>
                <label className="block text-sm font-medium mb-2">Agent auswählen</label>
                <select
                  value={selectedAgentId}
                  onChange={(e) => setSelectedAgentId(e.target.value)}
                  className="w-full px-4 py-2 border rounded-lg"
                >
                  <option value="">Agent auswählen...</option>
                  {agents?.map((agent) => (
                    <option key={agent.objectId} value={agent.objectId}>
                      {agent.firstName} {agent.lastName} ({agent.email})
                    </option>
                  ))}
                </select>
              </div>
              <Button
                onClick={handleBulkAssign}
                disabled={!selectedAgentId || assignMutation.isPending}
              >
                {assignMutation.isPending ? 'Wird zugewiesen...' : `${selectedTickets.size} Tickets zuweisen`}
              </Button>
            </div>
          )}

          {bulkAction === 'respond' && (
            <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
              <div>
                <label className="block text-sm font-medium mb-2">Antwort</label>
                <textarea
                  value={bulkResponse}
                  onChange={(e) => setBulkResponse(e.target.value)}
                  className="w-full h-32 px-4 py-2 border rounded-lg"
                  placeholder="Ihre Antwort..."
                />
              </div>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isInternal}
                  onChange={(e) => setIsInternal(e.target.checked)}
                />
                <span>Interner Kommentar</span>
              </label>
              <Button
                onClick={handleBulkRespond}
                disabled={!bulkResponse.trim() || respondMutation.isPending}
              >
                {respondMutation.isPending ? 'Wird gesendet...' : `Antwort zu ${selectedTickets.size} Tickets hinzufügen`}
              </Button>
            </div>
          )}
        </Card>
      )}

      {/* Ticket List */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold">Aktive Tickets</h2>
          <Button variant="secondary" size="sm" onClick={selectAll}>
            {selectedTickets.size === activeTickets.length ? 'Alle abwählen' : 'Alle auswählen'}
          </Button>
        </div>

        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        ) : activeTickets.length === 0 ? (
          <div className="text-center py-8 text-gray-500">Keine aktiven Tickets</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left">
                    <input
                      type="checkbox"
                      checked={selectedTickets.size === activeTickets.length && activeTickets.length > 0}
                      onChange={selectAll}
                      className="rounded"
                    />
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ticket</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Betreff</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Priorität</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Kunde</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Erstellt</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {activeTickets.map((ticket) => (
                  <tr
                    key={ticket.objectId}
                    className={`hover:bg-gray-50 ${selectedTickets.has(ticket.objectId) ? 'bg-blue-50' : ''}`}
                  >
                    <td className="px-4 py-4">
                      <input
                        type="checkbox"
                        checked={selectedTickets.has(ticket.objectId)}
                        onChange={() => toggleTicket(ticket.objectId)}
                        className="rounded"
                      />
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <button
                        onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                        className="text-sm font-mono text-fin1-primary hover:underline"
                      >
                        #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                      </button>
                    </td>
                    <td className="px-6 py-4">
                      <p className="text-sm text-gray-900">{ticket.subject}</p>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Badge variant={getStatusVariant(ticket.status)}>
                        {ticket.status}
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
                      {formatDateTime(ticket.createdAt)}
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
