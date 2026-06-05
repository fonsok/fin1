import { useState, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card, Button, Badge, TicketPriorityBadge, TicketStatusBadge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import { useAuth } from '../../../context/AuthContext';
import { tableBodyCellMutedClasses, tableBodyCellPrimaryClasses } from '../../../utils/tableStriping';
import {
  getTicket,
  respondToTicket,
  assignTicket,
  escalateTicket,
  resolveTicket,
  closeTicket,
  getAvailableAgents,
  getCustomerProfile,
} from '../api';
import { getResponseTemplates } from '../../Templates/api';
import { sortByTitleDe } from '../../Templates/utils/templateDisplayOrder';
import { TemplateDropdown, TemplateButton } from '../components/TemplateDropdown';
import {
  defaultDescriptionTemplates,
  type TicketDescriptionTemplate,
} from '../templates';
import {
  buildTicketTemplateContext,
  hydrateTicketTemplateText,
} from '../utils/hydrateTicketTemplate';
import {
  getTicketDisplayStatus,
  getTicketPriorityLabel,
  getTicketStatusLabel,
  isTicketEscalated,
} from '../../../utils/ticketLabels';

import { adminBorderChromeDeep, adminControlFieldPh500, adminEmphasisSoft, adminMuted, adminPrimary, adminSoft, adminStrong } from '../../../utils/adminThemeClasses';
export function TicketDetailPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const { user: agentUser } = useAuth();
  const { ticketId } = useParams<{ ticketId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [showRespondModal, setShowRespondModal] = useState(false);
  const [showResponseTemplates, setShowResponseTemplates] = useState(false);
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

  const {
    data: responseTemplates,
    error: templatesError,
    isLoading: templatesLoading,
  } = useQuery({
    queryKey: ['response-templates'],
    queryFn: () => getResponseTemplates('teamlead', true),
  });

  const descriptionTemplates: TicketDescriptionTemplate[] = useMemo(() => {
    if (responseTemplates && responseTemplates.length > 0) {
      return sortByTitleDe(
        responseTemplates
          .filter((t) => !!t.body && t.body.length > 0)
          .map((t) => ({ id: t.id, title: t.title, category: t.category, body: t.body! })),
      );
    }
    return sortByTitleDe(defaultDescriptionTemplates);
  }, [responseTemplates]);

  const { data: customerProfile } = useQuery({
    queryKey: ['customer-profile', ticket?.userId],
    queryFn: () => getCustomerProfile(ticket!.userId),
    enabled: !!ticket?.userId,
  });

  const templateContext = useMemo(
    () =>
      buildTicketTemplateContext({
        customerProfile: customerProfile ?? null,
        customer: customerProfile
          ? {
              objectId: customerProfile.objectId,
              userId: customerProfile.userId,
              customerNumber: customerProfile.customerNumber,
              email: customerProfile.email,
              firstName: customerProfile.firstName,
              lastName: customerProfile.lastName,
              fullName: customerProfile.fullName,
              status: customerProfile.status,
              role: customerProfile.role,
              kycStatus: customerProfile.kycStatus,
            }
          : ticket
            ? {
                objectId: ticket.userId,
                userId: ticket.userId,
                customerNumber: '',
                email: ticket.userEmail || '',
                status: '',
                role: '',
              }
            : null,
        agent: agentUser,
        ticketNumber: ticket?.ticketNumber,
      }),
    [customerProfile, ticket, agentUser],
  );

  const handleResponseTemplateSelect = (template: TicketDescriptionTemplate): void => {
    if (!template.body) return;
    const hydratedBody = hydrateTicketTemplateText(template.body, templateContext);
    setResponseText((prev) => (prev.trim() ? `${prev}\n\n${hydratedBody}` : hydratedBody));
    setShowResponseTemplates(false);
  };

  const respondMutation = useMutation({
    mutationFn: () => respondToTicket(ticketId!, responseText, isInternal),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      queryClient.invalidateQueries({ queryKey: ['tickets'] });
      setShowRespondModal(false);
      setShowResponseTemplates(false);
      setResponseText('');
      setIsInternal(false);
    },
  });

  const assignMutation = useMutation({
    mutationFn: () => assignTicket(ticketId!, selectedAgentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      queryClient.invalidateQueries({ queryKey: ['tickets'] });
      setShowAssignModal(false);
      setSelectedAgentId('');
    },
  });

  const escalateMutation = useMutation({
    mutationFn: () => escalateTicket(ticketId!, escalationReason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      queryClient.invalidateQueries({ queryKey: ['tickets'] });
      setShowEscalateModal(false);
      setEscalationReason('');
    },
  });

  const resolveMutation = useMutation({
    mutationFn: () => resolveTicket(ticketId!, resolutionNote, false),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      queryClient.invalidateQueries({ queryKey: ['tickets'] });
      setShowResolveModal(false);
      setResolutionNote('');
    },
  });

  const closeMutation = useMutation({
    mutationFn: () => closeTicket(ticketId!, resolutionNote),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ticket', ticketId] });
      queryClient.invalidateQueries({ queryKey: ['tickets'] });
      navigate('/csr/tickets');
    },
  });

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen gap-3">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
        <p className={clsx('text-sm', adminMuted(isDark))}>Laden...</p>
      </div>
    );
  }

  if (!ticket) {
    return (
      <Card>
        <div className="text-center py-8">
          <p className={clsx(adminMuted(isDark))}>Ticket nicht gefunden</p>
          <Button onClick={() => navigate('/csr/tickets')} className="mt-4">
            Zurück zur Liste
          </Button>
        </div>
      </Card>
    );
  }

  const displayStatus = getTicketDisplayStatus(ticket);
  const ticketEscalated = isTicketEscalated(ticket);
  const canEdit = ticket.status !== 'closed' && ticket.status !== 'archived';

  const fieldSurface = clsx(
    'w-full border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
    adminControlFieldPh500(isDark),
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <button
            type="button"
            onClick={() => navigate('/csr/tickets')}
            className={clsx(
              'mb-2 hover:underline',
              isDark ? 'text-sky-400 hover:text-sky-300' : 'text-fin1-primary',
            )}
          >
            ← Zurück zur Liste
          </button>
          <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>
            Ticket #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
          </h1>
        </div>
        <div className="flex gap-2">
          <TicketStatusBadge status={displayStatus}>
            {getTicketStatusLabel(displayStatus)}
          </TicketStatusBadge>
          <TicketPriorityBadge priority={ticket.priority}>
            {getTicketPriorityLabel(ticket.priority)}
          </TicketPriorityBadge>
        </div>
      </div>

      {/* Ticket Info */}
      <Card>
        <div className="space-y-4">
          <div>
            <h2 className={clsx('text-lg font-semibold mb-2', adminPrimary(isDark))}>
              {ticket.subject}
            </h2>
            <p className={clsx('whitespace-pre-wrap', adminSoft(isDark))}>
              {ticket.description}
            </p>
          </div>

          <div className={clsx('grid grid-cols-2 gap-4 pt-4 border-t', adminBorderChromeDeep(isDark))}>
            <div>
              <div className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>Kunde</div>
              <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>
                {ticket.userEmail || ticket.userId}
              </div>
            </div>
            <div>
              <div className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>Kategorie</div>
              <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>{ticket.category}</div>
            </div>
            <div>
              <div className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>Erstellt</div>
              <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>
                {formatDateTime(ticket.createdAt)}
              </div>
            </div>
            <div>
              <div className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>Zugewiesen</div>
              <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>
                {ticket.assignedToName || ticket.assignedTo || 'Nicht zugewiesen'}
              </div>
            </div>
          </div>
        </div>
      </Card>

      {ticketEscalated && (
        <Card>
          <h2 className={clsx('text-lg font-semibold mb-3', isDark ? 'text-red-300' : 'text-red-700')}>
            Eskalation
          </h2>
          <div className={clsx('space-y-3 text-sm', adminSoft(isDark))}>
            {ticket.escalationReason && (
              <p className="whitespace-pre-wrap">{ticket.escalationReason}</p>
            )}
            <div className={clsx('grid grid-cols-2 gap-4 pt-2 border-t', adminBorderChromeDeep(isDark))}>
              {ticket.escalatedAt && (
                <div>
                  <div className={tableBodyCellMutedClasses(isDark)}>Eskaliert am</div>
                  <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>
                    {formatDateTime(ticket.escalatedAt)}
                  </div>
                </div>
              )}
              {(ticket.escalatedByName || ticket.escalatedBy) && (
                <div>
                  <div className={tableBodyCellMutedClasses(isDark)}>Eskaliert von</div>
                  <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>
                    {ticket.escalatedByName || ticket.escalatedBy}
                  </div>
                </div>
              )}
            </div>
          </div>
        </Card>
      )}

      {/* Comments */}
      <Card>
        <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>Kommentare</h2>
        <div className="space-y-4">
          {ticket.comments?.map((comment) => (
            <div
              key={comment.objectId}
              className={clsx(
                'p-4 rounded-lg border',
                comment.isInternal
                  ? isDark
                    ? 'bg-amber-950/35 border-amber-800/80'
                    : 'bg-yellow-50 border-yellow-200'
                  : isDark
                    ? 'bg-slate-800/60 border-slate-600'
                    : 'bg-gray-50 border-gray-200',
              )}
            >
              <div className="flex items-center justify-between mb-2">
                <div className={clsx('font-medium', tableBodyCellPrimaryClasses(isDark))}>
                  {comment.createdByName || comment.createdBy}
                </div>
                <div className={clsx('text-sm', tableBodyCellMutedClasses(isDark))}>
                  {formatDateTime(comment.createdAt)}
                </div>
              </div>
              {comment.isInternal && (
                <Badge variant="warning" className="mb-2">Intern</Badge>
              )}
              <p className={clsx('whitespace-pre-wrap', adminStrong(isDark))}>
                {comment.content}
              </p>
            </div>
          ))}
          {(!ticket.comments || ticket.comments.length === 0) && (
            <p className={clsx('text-center py-4', tableBodyCellMutedClasses(isDark))}>Keine Kommentare</p>
          )}
        </div>
      </Card>

      {/* Actions */}
      {canEdit && (
        <Card>
          <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>Aktionen</h2>
          <div className="flex flex-wrap gap-2">
            <Button onClick={() => setShowRespondModal(true)}>
              Antworten
            </Button>
            <Button variant="secondary" onClick={() => setShowAssignModal(true)}>
              Zuweisen
            </Button>
            {!ticketEscalated && (
              <Button variant="secondary" onClick={() => setShowEscalateModal(true)}>
                Eskalieren
              </Button>
            )}
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
            <div className="flex items-center justify-between mb-4">
              <h2 className={clsx('text-xl font-semibold', adminPrimary(isDark))}>
                Antwort hinzufügen
              </h2>
              <div className="relative">
                <TemplateButton onClick={() => setShowResponseTemplates(!showResponseTemplates)} />
                {showResponseTemplates && (
                  <TemplateDropdown
                    title="Antwort-Vorlagen"
                    templates={descriptionTemplates}
                    isLoading={templatesLoading}
                    error={templatesError ? 'Fehler beim Laden der Vorlagen' : null}
                    onSelect={handleResponseTemplateSelect}
                    onClose={() => setShowResponseTemplates(false)}
                    showBodyPreview
                    widthClass="w-80"
                  />
                )}
              </div>
            </div>
            <textarea
              value={responseText}
              onChange={(e) => setResponseText(e.target.value)}
              className={clsx('h-32 p-3 mb-4', fieldSurface)}
              placeholder="Ihre Antwort..."
            />
            <label className={clsx('flex items-center gap-2 mb-4', adminEmphasisSoft(isDark))}>
              <input
                type="checkbox"
                checked={isInternal}
                onChange={(e) => setIsInternal(e.target.checked)}
                className="rounded"
              />
              <span>Interner Kommentar (nicht für Kunde sichtbar)</span>
            </label>
            <div className="flex gap-2 justify-end">
              <Button
                variant="secondary"
                onClick={() => {
                  setShowRespondModal(false);
                  setShowResponseTemplates(false);
                }}
              >
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
            <h2 className={clsx('text-xl font-semibold mb-4', adminPrimary(isDark))}>
              Ticket zuweisen
            </h2>
            <select
              value={selectedAgentId}
              onChange={(e) => setSelectedAgentId(e.target.value)}
              className={clsx('p-3 mb-4', fieldSurface)}
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
            <h2 className={clsx('text-xl font-semibold mb-4', adminPrimary(isDark))}>
              Ticket eskalieren
            </h2>
            <textarea
              value={escalationReason}
              onChange={(e) => setEscalationReason(e.target.value)}
              className={clsx('h-32 p-3 mb-4', fieldSurface)}
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
            <h2 className={clsx('text-xl font-semibold mb-4', adminPrimary(isDark))}>
              Ticket lösen
            </h2>
            <textarea
              value={resolutionNote}
              onChange={(e) => setResolutionNote(e.target.value)}
              className={clsx('h-32 p-3 mb-4', fieldSurface)}
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
