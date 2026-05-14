import { useState, useMemo, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import clsx from 'clsx';
import { Card, Button, Badge, PaginationBar } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime, formatNumber } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMutedClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { getSupportTickets, assignTicket, getAvailableAgents } from '../api';

import { adminControlField, adminEmptyIcon, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
export function TicketQueuePage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [selectedTicketId, setSelectedTicketId] = useState<string | null>(null);
  const [selectedAgentId, setSelectedAgentId] = useState('');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(25);

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

  const unassignedTickets = useMemo(
    () =>
      (tickets || []).filter(
        (t) => !t.assignedTo && t.status !== 'resolved' && t.status !== 'closed' && t.status !== 'archived'
      ),
    [tickets]
  );

  const serverTicketTotal = (tickets || []).length;
  const queueTotal = unassignedTickets.length;
  const queueTotalPages = Math.max(1, Math.ceil(queueTotal / pageSize));
  const pagedQueueTickets = useMemo(
    () => unassignedTickets.slice(page * pageSize, (page + 1) * pageSize),
    [unassignedTickets, page, pageSize]
  );

  useEffect(() => {
    if (page > 0 && page >= queueTotalPages) {
      setPage(Math.max(0, queueTotalPages - 1));
    }
  }, [page, queueTotalPages]);

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
      <div className="flex flex-col items-center justify-center min-h-screen gap-3">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
        <p className={clsx('text-sm', adminMuted(isDark))}>Laden...</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Ticket-Warteschlange</h1>
        <Badge variant="warning">{unassignedTickets.length} unzugewiesen</Badge>
      </div>

      <Card padding="none">
        {unassignedTickets.length === 0 ? (
          <div className="text-center py-8">
            <svg
              className={clsx('w-12 h-12 mx-auto mb-4', adminEmptyIcon(isDark))}
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
            <p className={clsx(adminMuted(isDark))}>Keine unzugewiesenen Tickets</p>
          </div>
        ) : (
          <>
          <div
            className={clsx(
              'flex flex-wrap items-center gap-3 justify-between border-b px-3 py-2',
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
                adminControlField(isDark),
              )}
            >
              <option value={25}>25 / Seite</option>
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
            </select>
            <p className={clsx('text-sm text-right', adminMuted(isDark))}>
              {formatNumber(queueTotal)} Treffer nach Filter · bis zu {formatNumber(serverTicketTotal)} aus Server (
              {formatNumber(pageSize)} pro Seite, lokal)
            </p>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className={tableTheadSurfaceClasses(isDark)}>
                <tr>
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
                  <th
                    className={clsx(
                      'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                      tableHeaderCellTextClasses(isDark),
                    )}
                  >
                    Aktionen
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {pagedQueueTickets.map((ticket, index) => (
                  <tr key={ticket.objectId} className={listRowStripeClasses(isDark, index)}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={clsx('text-sm font-mono', isDark ? 'text-sky-400' : 'text-fin1-primary')}>
                        #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <button
                        type="button"
                        onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                        className={clsx(
                          'text-sm hover:underline',
                          isDark
                            ? 'text-slate-100 hover:text-sky-300'
                            : 'text-gray-900 hover:text-fin1-primary',
                        )}
                      >
                        {ticket.subject}
                      </button>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Badge variant={getPriorityVariant(ticket.priority)}>
                        {getPriorityLabel(ticket.priority)}
                      </Badge>
                    </td>
                    <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                      {ticket.userEmail || ticket.userId}
                    </td>
                    <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
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
                          className={clsx(
                            'text-sm border rounded px-2 py-1',
                            adminControlField(isDark),
                          )}
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
            <PaginationBar
              page={page}
              pageSize={pageSize}
              total={queueTotal}
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
