import { useState, useMemo, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import clsx from 'clsx';
import { Card, PaginationBar, TicketPriorityBadge, TicketStatusBadge } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime, formatNumber } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMutedClasses,
  tableBodyCellPrimaryClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { getSupportTickets } from '../api';

import { adminControlField, adminMuted, adminPrimary, adminSurfaceWell } from '../../../utils/adminThemeClasses';
export function TicketArchivePage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const [statusFilter, setStatusFilter] = useState<'resolved' | 'closed' | 'all'>('all');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(25);

  const { data: tickets, isLoading } = useQuery({
    queryKey: ['csr-tickets-archive', statusFilter],
    queryFn: () => getSupportTickets(),
  });

  const archivedTickets = useMemo(
    () =>
      (tickets || []).filter((t) => {
        if (statusFilter === 'all') {
          return t.status === 'resolved' || t.status === 'closed' || t.status === 'archived';
        }
        return t.status === statusFilter;
      }),
    [tickets, statusFilter]
  );

  const serverTicketTotal = (tickets || []).length;
  const archiveTotal = archivedTickets.length;
  const archiveTotalPages = Math.max(1, Math.ceil(archiveTotal / pageSize));
  const pagedArchivedTickets = useMemo(
    () => archivedTickets.slice(page * pageSize, (page + 1) * pageSize),
    [archivedTickets, page, pageSize]
  );

  useEffect(() => {
    setPage(0);
  }, [statusFilter]);

  useEffect(() => {
    if (page > 0 && page >= archiveTotalPages) {
      setPage(Math.max(0, archiveTotalPages - 1));
    }
  }, [page, archiveTotalPages]);

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
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Ticket-Archiv</h1>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'resolved' | 'closed' | 'all')}
          className={clsx(
            'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
            adminControlField(isDark),
          )}
        >
          <option value="all">Alle</option>
          <option value="resolved">Gelöst</option>
          <option value="closed">Geschlossen</option>
        </select>
      </div>

      <Card padding="none">
        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className={clsx('mt-4 text-sm', adminMuted(isDark))}>Laden...</p>
          </div>
        ) : archivedTickets.length === 0 ? (
          <div className="text-center py-8">
            <p className={clsx(adminMuted(isDark))}>Keine archivierten Tickets gefunden</p>
          </div>
        ) : (
          <>
            <div
              className={clsx(
                'flex flex-wrap items-center gap-3 justify-between border-b px-3 py-2',
                adminSurfaceWell(isDark),
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
                {formatNumber(archiveTotal)} Treffer nach Filter · bis zu {formatNumber(serverTicketTotal)} aus Server (
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
                      Geschlossen
                    </th>
                  </tr>
                </thead>
                <tbody className={tableBodyDivideClasses(isDark)}>
                  {pagedArchivedTickets.map((ticket, index) => (
                    <tr
                      key={ticket.objectId}
                      onClick={() => navigate(`/csr/tickets/${ticket.objectId}`)}
                      className={listRowStripeClasses(isDark, index, { className: 'cursor-pointer' })}
                    >
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={clsx('text-sm font-mono', isDark ? 'text-sky-400' : 'text-fin1-primary')}>
                          #{ticket.ticketNumber || ticket.objectId.slice(0, 8)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <p className={clsx('text-sm', tableBodyCellPrimaryClasses(isDark))}>
                          {ticket.subject}
                        </p>
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
                        {ticket.userEmail || ticket.userId}
                      </td>
                      <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                        {ticket.closedAt
                          ? formatDateTime(ticket.closedAt)
                          : ticket.resolvedAt
                            ? formatDateTime(ticket.resolvedAt)
                            : '-'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <PaginationBar
              page={page}
              pageSize={pageSize}
              total={archiveTotal}
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
