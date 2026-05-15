import { useCallback, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate, useLocation } from 'react-router-dom';
import clsx from 'clsx';
import { getTickets } from '../../api/admin';
import { Card, Button, PaginationBar, TicketPriorityBadge, TicketStatusBadge } from '../../components/ui';
import { SortableTh, nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { formatDateTime } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import { useAuth } from '../../context/AuthContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMutedClasses,
  tableBodyCellPrimaryClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';

import { adminControlField, adminEmptyIcon, adminMonoHint, adminMuted } from '../../utils/adminThemeClasses';
export function TicketListPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const { user } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const isCSRRoute = location.pathname.startsWith('/csr');
  /** Business Admin: dieselbe Listenansicht wie früher beim Admin, aber ohne Ticket-Detail/Bearbeitung (CSR). */
  const isTicketsReadOnlyOverview = !isCSRRoute && user?.role === 'business_admin';
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [priorityFilter, setPriorityFilter] = useState<string>('');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['tickets', statusFilter, priorityFilter, page, pageSize, sortBy, sortOrder],
    queryFn: () =>
      getTickets({
        status: statusFilter || undefined,
        priority: priorityFilter || undefined,
        limit: pageSize,
        skip: page * pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
  });
  const total = data?.total ?? 0;

  const onSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sortBy, sortOrder);
      setSortBy(next.sortBy);
      setSortOrder(next.sortOrder);
      setPage(0);
    },
    [sortBy, sortOrder],
  );

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

  return (
    <div className="space-y-6">
      {/* Filters */}
      <Card>
        <div className="flex flex-col sm:flex-row gap-4">
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              adminControlField(isDark),
            )}
          >
            <option value="">Alle Status</option>
            <option value="open">Offen</option>
            <option value="in_progress">In Bearbeitung</option>
            <option value="waiting">Wartend</option>
            <option value="resolved">Gelöst</option>
            <option value="closed">Geschlossen</option>
          </select>

          <select
            value={priorityFilter}
            onChange={(e) => {
              setPriorityFilter(e.target.value);
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              adminControlField(isDark),
            )}
          >
            <option value="">Alle Prioritäten</option>
            <option value="urgent">Dringend</option>
            <option value="high">Hoch</option>
            <option value="medium">Mittel</option>
            <option value="low">Niedrig</option>
          </select>

          <Button variant="secondary" onClick={() => refetch()}>
            Aktualisieren
          </Button>
          <select
            value={pageSize}
            onChange={(e) => {
              setPageSize(Number(e.target.value));
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              adminControlField(isDark),
            )}
          >
            <option value={50}>50 / Seite</option>
            <option value={100}>100 / Seite</option>
            <option value={250}>250 / Seite</option>
          </select>
        </div>
      </Card>

      {isTicketsReadOnlyOverview && (
        <p className={clsx('text-sm', adminMonoHint(isDark))}>
          Nur Überblick über offene und laufende Tickets. Erstellung und Bearbeitung erfolgt durch den
          Kundenservice (CSR).
        </p>
      )}

      {/* Results */}
      <Card padding="none">
        {isLoading ? (
          <div className="p-8 text-center">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className={clsx('mt-4', adminMuted(isDark))}>Laden...</p>
          </div>
        ) : error ? (
          <div className="p-8 text-center">
            <p className={clsx(isDark ? 'text-red-400' : 'text-red-500')}>Fehler beim Laden der Tickets</p>
            <p className={clsx('text-sm mt-2', adminMuted(isDark))}>
              {error instanceof Error ? error.message : 'Unbekannter Fehler'}
            </p>
          </div>
        ) : !data?.tickets?.length ? (
          <div className="p-8 text-center">
            <svg
              className={clsx('w-12 h-12 mx-auto mb-4', adminEmptyIcon(isDark))}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" />
            </svg>
            <p className={clsx(adminMuted(isDark))}>Keine Tickets gefunden</p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className={tableTheadSurfaceClasses(isDark)}>
                  <tr>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Ticket
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Betreff
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Status
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Priorität
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Zugewiesen
                    </th>
                    <SortableTh
                      label="Erstellt"
                      field="createdAt"
                      sortBy={sortBy}
                      sortOrder={sortOrder}
                      onSort={onSort}
                      className={clsx('px-6 py-3', tableHeaderCellTextClasses(isDark))}
                    />
                  </tr>
                </thead>
                <tbody className={tableBodyDivideClasses(isDark)}>
                  {data.tickets.map((ticket, index: number) => (
                    <tr
                      key={ticket.objectId}
                      className={listRowStripeClasses(isDark, index, {
                        className: isTicketsReadOnlyOverview ? '' : 'cursor-pointer',
                      })}
                      onClick={
                        isTicketsReadOnlyOverview
                          ? undefined
                          : () =>
                              navigate(
                                isCSRRoute ? `/csr/tickets/${ticket.objectId}` : `/tickets/${ticket.objectId}`,
                              )
                      }
                    >
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={clsx('text-sm font-mono', isDark ? 'text-sky-400' : 'text-fin1-primary')}>
                          #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <p className={clsx('text-sm truncate max-w-xs', tableBodyCellPrimaryClasses(isDark))}>
                          {ticket.subject || 'Kein Betreff'}
                        </p>
                        {ticket.userEmail && (
                          <p className={clsx('text-xs', tableBodyCellMutedClasses(isDark))}>{ticket.userEmail}</p>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <TicketStatusBadge status={ticket.status}>
                          {getTicketStatusLabel(ticket.status)}
                        </TicketStatusBadge>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <TicketPriorityBadge priority={ticket.priority}>
                          {getPriorityLabel(ticket.priority)}
                        </TicketPriorityBadge>
                      </td>
                      <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                        {ticket.assignedToName || ticket.assignedTo || '-'}
                      </td>
                      <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                        {formatDateTime(ticket.createdAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <PaginationBar
              page={page}
              pageSize={pageSize}
              total={total}
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
