import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Card, Button, Badge, getStatusVariant } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { getTicket, respondToTicket, assignTicket, escalateTicket, resolveTicket, closeTicket, getAvailableAgents } from '../api';

export function TicketDetailPage() {
  const { ticketId } = useParams<{ ticketId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [showRespondModal, setShowRespondModal] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [showEscalateModal, setShowEscalateModal] = useState(false);
  const [showResolveModal, setShowResolveModal] = useState(false);
  const [responseText, setResponseText] = useState('');
  const [isInternal, setIsInternal] = useState(false);
  const [selectedAgentId, setSelectedAgentId] = useState('');
  const [escalationReason, setEscalationReason] = useState('');
  const [resolutionNote, setResolutionNote] = useState('');

  const { data: ticket, isLoading } = useQuery({
    queryKey: ['ticket', ticketId],
    queryFn: () => getTicket(ticketId!),
    enabled: !!ticketId,
  });

  const { data: agents } = useQuery({
    queryKey: ['csr-agents'],
    queryFn: () => getAvailableAgents(),
  });

  const respondMutation = useMutation({
    mutationFn: () => respondToTicket(ticketId!, responseText, isInternal),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      setShowRespondModal(false);
      setResponseText('');
      setIsInternal(false);
    },
  });

  const assignMutation = useMutation({
    mutationFn: () => assignTicket(ticketId!, selectedAgentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      setShowAssignModal(false);
      setSelectedAgentId('');
    },
  });

  const escalateMutation = useMutation({
    mutationFn: () => escalateTicket(ticketId!, escalationReason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      setShowEscalateModal(false);
      setEscalationReason('');
    },
  });

  const resolveMutation = useMutation({
    mutationFn: () => resolveTicket(ticketId!, resolutionNote, false),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      setShowResolveModal(false);
      setResolutionNote('');
    },
  });

  const closeMutation = useMutation({
    mutationFn: () => closeTicket(ticketId!, resolutionNote),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      navigate('/csr/tickets');
    },
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  if (!ticket) {
    return (
      <Card>
        <div className="text-center py-8">
          <p className="text-gray-500">Ticket nicht gefunden</p>
          <Button onClick={() => navigate('/csr/tickets')} className="mt-4">
            Zurück zur Liste
          </Button>
        </div>
      </Card>
    );
  }

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

  const canEdit = ticket.status !== 'closed' && ticket.status !== 'archived';

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <button
            onClick={() => navigate('/csr/tickets')}
            className="text-fin1-primary hover:underline mb-2"
          >
            ← Zurück zur Liste
          </button>
          <h1 className="text-2xl font-bold">
            Ticket #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
          </h1>
        </div>
        <div className="flex gap-2">
          <Badge variant={getStatusVariant(ticket.status)}>
            {getTicketStatusLabel(ticket.status)}
          </Badge>
          <Badge variant={getPriorityVariant(ticket.priority)}>
            {getPriorityLabel(ticket.priority)}
          </Badge>
        </div>
      </div>

      {/* Ticket Info */}
      <Card>
        <div className="space-y-4">
          <div>
            <h2 className="text-lg font-semibold mb-2">{ticket.subject}</h2>
            <p className="text-gray-600 whitespace-pre-wrap">{ticket.description}</p>
          </div>

          <div className="grid grid-cols-2 gap-4 pt-4 border-t">
            <div>
              <div className="text-sm text-gray-500">Kunde</div>
              <div className="font-medium">{ticket.userEmail || ticket.userId}</div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Kategorie</div>
              <div className="font-medium">{ticket.category}</div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Erstellt</div>
              <div className="font-medium">{formatDateTime(ticket.createdAt)}</div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Zugewiesen</div>
              <div className="font-medium">{ticket.assignedToName || ticket.assignedTo || 'Nicht zugewiesen'}</div>
            </div>
          </div>
        </div>
      </Card>

      {/* Comments */}
      <Card>
        <h2 className="text-lg font-semibold mb-4">Kommentare</h2>
        <div className="space-y-4">
          {ticket.comments?.map((comment) => (
            <div
              key={comment.objectId}
              className={`p-4 rounded-lg ${
                comment.isInternal ? 'bg-yellow-50 border border-yellow-200' : 'bg-gray-50'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <div className="font-medium">{comment.createdByName || comment.createdBy}</div>
                <div className="text-sm text-gray-500">{formatDateTime(comment.createdAt)}</div>
              </div>
              {comment.isInternal && (
                <Badge variant="warning" className="mb-2">Intern</Badge>
              )}
              <p className="text-gray-700 whitespace-pre-wrap">{comment.content}</p>
            </div>
          ))}
          {(!ticket.comments || ticket.comments.length === 0) && (
            <p className="text-gray-500 text-center py-4">Keine Kommentare</p>
          )}
        </div>
      </Card>

      {/* Actions */}
      {canEdit && (
        <Card>
          <h2 className="text-lg font-semibold mb-4">Aktionen</h2>
          <div className="flex flex-wrap gap-2">
            <Button onClick={() => setShowRespondModal(true)}>
              Antworten
            </Button>
            <Button variant="secondary" onClick={() => setShowAssignModal(true)}>
              Zuweisen
            </Button>
            <Button variant="secondary" onClick={() => setShowEscalateModal(true)}>
              Eskalieren
            </Button>
            {ticket.status === 'resolved' ? (
              <Button variant="secondary" onClick={() => closeMutation.mutate()}>
                Schließen
              </Button>
            ) : (
              <Button variant="secondary" onClick={() => setShowResolveModal(true)}>
                Lösen
              </Button>
            )}
          </div>
        </Card>
      )}

      {/* Respond Modal */}
      {showRespondModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-2xl m-4">
            <h2 className="text-xl font-semibold mb-4">Antwort hinzufügen</h2>
            <textarea
              value={responseText}
              onChange={(e) => setResponseText(e.target.value)}
              className="w-full h-32 p-3 border rounded-lg mb-4"
              placeholder="Ihre Antwort..."
            />
            <label className="flex items-center gap-2 mb-4">
              <input
                type="checkbox"
                checked={isInternal}
                onChange={(e) => setIsInternal(e.target.checked)}
              />
              <span>Interner Kommentar (nicht für Kunde sichtbar)</span>
            </label>
            <div className="flex gap-2 justify-end">
              <Button variant="secondary" onClick={() => setShowRespondModal(false)}>
                Abbrechen
              </Button>
              <Button
                onClick={() => respondMutation.mutate()}
                disabled={!responseText.trim() || respondMutation.isPending}
              >
                {respondMutation.isPending ? 'Wird gesendet...' : 'Senden'}
              </Button>
            </div>
          </Card>
        </div>
      )}

      {/* Assign Modal */}
      {showAssignModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-md m-4">
            <h2 className="text-xl font-semibold mb-4">Ticket zuweisen</h2>
            <select
              value={selectedAgentId}
              onChange={(e) => setSelectedAgentId(e.target.value)}
              className="w-full p-3 border rounded-lg mb-4"
            >
              <option value="">Agent auswählen...</option>
              {agents?.map((agent) => (
                <option key={agent.objectId} value={agent.objectId}>
                  {agent.firstName} {agent.lastName} ({agent.email})
                </option>
              ))}
            </select>
            <div className="flex gap-2 justify-end">
              <Button variant="secondary" onClick={() => setShowAssignModal(false)}>
                Abbrechen
              </Button>
              <Button
                onClick={() => assignMutation.mutate()}
                disabled={!selectedAgentId || assignMutation.isPending}
              >
                {assignMutation.isPending ? 'Wird zugewiesen...' : 'Zuweisen'}
              </Button>
            </div>
          </Card>
        </div>
      )}

      {/* Escalate Modal */}
      {showEscalateModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-md m-4">
            <h2 className="text-xl font-semibold mb-4">Ticket eskalieren</h2>
            <textarea
              value={escalationReason}
              onChange={(e) => setEscalationReason(e.target.value)}
              className="w-full h-32 p-3 border rounded-lg mb-4"
              placeholder="Grund für Eskalation..."
            />
            <div className="flex gap-2 justify-end">
              <Button variant="secondary" onClick={() => setShowEscalateModal(false)}>
                Abbrechen
              </Button>
              <Button
                onClick={() => escalateMutation.mutate()}
                disabled={!escalationReason.trim() || escalateMutation.isPending}
              >
                {escalateMutation.isPending ? 'Wird eskaliert...' : 'Eskalieren'}
              </Button>
            </div>
          </Card>
        </div>
      )}

      {/* Resolve Modal */}
      {showResolveModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-md m-4">
            <h2 className="text-xl font-semibold mb-4">Ticket lösen</h2>
            <textarea
              value={resolutionNote}
              onChange={(e) => setResolutionNote(e.target.value)}
              className="w-full h-32 p-3 border rounded-lg mb-4"
              placeholder="Lösungsbeschreibung..."
            />
            <div className="flex gap-2 justify-end">
              <Button variant="secondary" onClick={() => setShowResolveModal(false)}>
                Abbrechen
              </Button>
              <Button
                onClick={() => resolveMutation.mutate()}
                disabled={!resolutionNote.trim() || resolveMutation.isPending}
              >
                {resolveMutation.isPending ? 'Wird gelöst...' : 'Lösen'}
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
