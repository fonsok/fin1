import { useState, useMemo, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import clsx from 'clsx';
import { Card, Button, Badge, PaginationBar, getStatusVariant } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime, formatNumber } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { getSupportTickets, assignTicket, respondToTicket, getAvailableAgents } from '../api';

import { adminEmphasisSoft, adminMuted, adminPrimary, adminStrong } from '../../../utils/adminThemeClasses';
export function BulkOperationsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const bulkPanel = clsx(
    'space-y-4 p-4 rounded-lg border',
    isDark ? 'bg-slate-900/50 border-slate-600' : 'bg-gray-50 border-gray-200',
  );
  const bulkControl = clsx(
    'w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
    isDark
      ? 'bg-slate-900/70 border-slate-600 text-slate-100 placeholder:text-slate-400'
      : 'bg-white border-gray-300 text-gray-900',
  );
  const bulkTextarea = clsx(
    'w-full h-32 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
    isDark
      ? 'bg-slate-900/70 border-slate-600 text-slate-100 placeholder:text-slate-400'
      : 'bg-white border-gray-300 text-gray-900',
  );
  const fieldLabel = clsx('block text-sm font-medium mb-2', adminStrong(isDark));
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [selectedTickets, setSelectedTickets] = useState<Set<string>>(new Set());
  const [bulkAction, setBulkAction] = useState<'assign' | 'respond' | 'none'>('none');
  const [selectedAgentId, setSelectedAgentId] = useState('');
  const [bulkResponse, setBulkResponse] = useState('');
  const [isInternal, setIsInternal] = useState(false);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(25);

  const { data: tickets, isLoading } = useQuery({
    queryKey: ['csr-tickets-bulk'],
    queryFn: () => getSupportTickets(),
  });

  const { data: agents } = useQuery({
    queryKey: ['csr-agents'],
    queryFn: () => getAvailableAgents(),
  });

  const activeTickets = useMemo(
    () =>
      (tickets || []).filter(
        (t) => t.status !== 'resolved' && t.status !== 'closed' && t.status !== 'archived'
      ),
    [tickets]
  );

  const serverTicketTotal = (tickets || []).length;
  const listTotal = activeTickets.length;
  const listTotalPages = Math.max(1, Math.ceil(listTotal / pageSize));
  const pagedActiveTickets = useMemo(
    () => activeTickets.slice(page * pageSize, (page + 1) * pageSize),
    [activeTickets, page, pageSize]
  );

  useEffect(() => {
    if (page > 0 && page >= listTotalPages) {
      setPage(Math.max(0, listTotalPages - 1));
    }
  }, [page, listTotalPages]);

  const assignMutation = useMutation({
    mutationFn: async ({ ticketIds, agentId }: { ticketIds: string[]; agentId: string }) => {
      await Promise.all(ticketIds.map((id) => assignTicket(id, agentId)));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['csr-tickets'] });
      queryClient.invalidateQueries({ queryKey: ['csr-tickets-bulk'] });
      setSelectedTickets(new Set());
      setBulkAction('none');
      setSelectedAgentId('');
    },
  });

  const respondMutation = useMutation({
    mutationFn: async ({
      ticketIds,
      response,
      isInternal: internal,
    }: {
      ticketIds: string[];
      response: string;
      isInternal: boolean;
    }) => {
      await Promise.all(ticketIds.map((id) => respondToTicket(id, response, internal)));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['csr-tickets'] });
      queryClient.invalidateQueries({ queryKey: ['csr-tickets-bulk'] });
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
      setSelectedTickets(new Set(activeTickets.map((t) => t.objectId)));
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
      case 'urgent':
        return 'danger';
      case 'high':
        return 'danger';
      case 'medium':
        return 'warning';
      case 'low':
        return 'info';
      default:
        return 'neutral';
    }
  };

  const getPriorityLabel = (priority: string): string => {
    switch (priority?.toLowerCase()) {
      case 'urgent':
        return 'Dringend';
      case 'high':
        return 'Hoch';
      case 'medium':
        return 'Mittel';
      case 'low':
        return 'Niedrig';
      default:
        return priority || '-';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Massenbearbeitung</h1>
        <Badge variant="info">{selectedTickets.size} ausgewählt</Badge>
      </div>

      {/* Bulk Actions */}
      {selectedTickets.size > 0 && (
        <Card>
          <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>
            Massenaktionen
          </h2>
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
            <div className={bulkPanel}>
              <div>
                <label className={fieldLabel}>Agent auswählen</label>
                <select
                  value={selectedAgentId}
                  onChange={(e) => setSelectedAgentId(e.target.value)}
                  className={bulkControl}
                >
                  <option value="">Agent auswählen...</option>
                  {agents?.map((agent) => (
                    <option key={agent.objectId} value={agent.objectId}>
                      {agent.firstName} {agent.lastName} ({agent.email})
                    </option>
                  ))}
                </select>
              </div>
              <Button onClick={handleBulkAssign} disabled={!selectedAgentId || assignMutation.isPending}>
                {assignMutation.isPending ? 'Wird zugewiesen...' : `${selectedTickets.size} Tickets zuweisen`}
              </Button>
            </div>
          )}

          {bulkAction === 'respond' && (
            <div className={bulkPanel}>
              <div>
                <label className={fieldLabel}>Antwort</label>
                <textarea
                  value={bulkResponse}
                  onChange={(e) => setBulkResponse(e.target.value)}
                  className={bulkTextarea}
                  placeholder="Ihre Antwort..."
                />
              </div>
              <label className={clsx('flex items-center gap-2', adminEmphasisSoft(isDark))}>
                <input
                  type="checkbox"
                  checked={isInternal}
                  onChange={(e) => setIsInternal(e.target.checked)}
                />
                <span>Interner Kommentar</span>
              </label>
              <Button onClick={handleBulkRespond} disabled={!bulkResponse.trim() || respondMutation.isPending}>
                {respondMutation.isPending ? 'Wird gesendet...' : `Antwort zu ${selectedTickets.size} Tickets hinzufügen`}
              </Button>
            </div>
          )}
        </Card>
      )}

      {/* Ticket List */}
      <Card padding="none">
        <div className="flex items-center justify-between p-6 pb-4">
          <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
            Aktive Tickets
          </h2>
          <Button variant="secondary" size="sm" onClick={selectAll}>
            {selectedTickets.size === activeTickets.length && activeTickets.length > 0
              ? 'Alle abwählen'
              : 'Alle auswählen'}
          </Button>
        </div>

        {isLoading ? (
          <div className="text-center py-8 px-6">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          </div>
        ) : activeTickets.length === 0 ? (
          <div className={clsx('text-center py-8 px-6', adminMuted(isDark))}>
            Keine aktiven Tickets
          </div>
        ) : (
          <>
            <div
              className={clsx(
                'flex flex-wrap items-center gap-3 justify-between border-b px-3 py-2 mx-0',
                isDark ? 'border-slate-600 bg-slate-900/40' : 'border-gray-200 bg-gray-50',
              )}
            >
              <select
                value={pageSize}
                onChange={(e) => {
                  setPageSize(Number(e.target.value));
                  setPage(0);
                }}
                className={clsx(
                  'border rounded-lg px-3 py-2 text-sm',
                  isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
                )}
              >
                <option value={25}>25 / Seite</option>
                <option value={50}>50 / Seite</option>
                <option value={100}>100 / Seite</option>
              </select>
              <p className={clsx('text-sm text-right', adminMuted(isDark))}>
                {formatNumber(listTotal)} Treffer nach Filter · bis zu {formatNumber(serverTicketTotal)} aus Server (
                {formatNumber(pageSize)} pro Seite, lokal)
              </p>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className={tableTheadSurfaceClasses(isDark)}>
                  <tr>
                    <th className="px-4 py-3 text-left">
                      <input
                        type="checkbox"
                        checked={selectedTickets.size === activeTickets.length && activeTickets.length > 0}
                        onChange={selectAll}
                        className="rounded"
                        aria-label="Alle Tickets auswählen"
                      />
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Ticket
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Betreff
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Status
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Priorität
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Kunde
                    </th>
                    <th
                      className={clsx(
                        'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                        tableHeaderCellTextClasses(isDark),
                      )}
                    >
                      Erstellt
                    </th>
                  </tr>
                </thead>
                <tbody className={tableBodyDivideClasses(isDark)}>
                  {pagedActiveTickets.map((ticket, index) => {
                    const selected = selectedTickets.has(ticket.objectId);
                    return (
                      <tr
                        key={ticket.objectId}
                        className={clsx(
                          listRowStripeClasses(isDark, index),
                          selected && (isDark ? '!bg-blue-950/50' : '!bg-blue-50'),
                        )}
                      >
                        <td className="px-4 py-4">
                          <input
                            type="checkbox"
                            checked={selected}
                            onChange={() => toggleTicket(ticket.objectId)}
                            className="rounded"
                            aria-label={`Ticket ${ticket.ticketNumber || ticket.objectId} auswählen`}
                          />
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <button
                            type="button"
                            onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                            className="text-sm font-mono text-fin1-primary hover:underline"
                          >
                            #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                          </button>
                        </td>
                        <td className="px-6 py-4">
                          <p className={clsx('text-sm', adminPrimary(isDark))}>
                            {ticket.subject}
                          </p>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <Badge variant={getStatusVariant(ticket.status)}>{ticket.status}</Badge>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <Badge variant={getPriorityVariant(ticket.priority)}>
                            {getPriorityLabel(ticket.priority)}
                          </Badge>
                        </td>
                        <td
                          className={clsx(
                            'px-6 py-4 whitespace-nowrap text-sm',
                            adminMuted(isDark),
                          )}
                        >
                          {ticket.userEmail || ticket.userId}
                        </td>
                        <td
                          className={clsx(
                            'px-6 py-4 whitespace-nowrap text-sm',
                            adminMuted(isDark),
                          )}
                        >
                          {formatDateTime(ticket.createdAt)}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <PaginationBar
              page={page}
              pageSize={pageSize}
              total={listTotal}
              itemLabel="Tickets"
              isDark={isDark}
              onPageChange={setPage}
            />
          </>
        )}
      </Card>
    </div>
  );
}
