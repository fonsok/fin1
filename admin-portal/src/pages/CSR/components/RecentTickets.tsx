import { useState, useMemo, useEffect } from 'react';
import clsx from 'clsx';
import { Card, Badge, PaginationBar, getStatusVariant } from '../../../components/ui';
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
import type { SupportTicket } from '../types';
import { useNavigate } from 'react-router-dom';

import { adminCaption, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface RecentTicketsProps {
  tickets: SupportTicket[];
  /** Alle vom Endpoint geladenen Tickets (für „aus Server“-Hinweis) */
  serverTicketTotal: number;
  isLoading: boolean;
}

export function RecentTickets({ tickets, serverTicketTotal, isLoading }: RecentTicketsProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(25);

  const listTotal = tickets.length;
  const listTotalPages = Math.max(1, Math.ceil(listTotal / pageSize));
  const pagedTickets = useMemo(
    () => tickets.slice(page * pageSize, (page + 1) * pageSize),
    [tickets, page, pageSize]
  );

  useEffect(() => {
    if (page > 0 && page >= listTotalPages) {
      setPage(Math.max(0, listTotalPages - 1));
    }
  }, [page, listTotalPages]);

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

  const getTicketStatusLabel = (status: string): string => {
    switch (status?.toLowerCase()) {
      case 'open':
        return 'Offen';
      case 'in_progress':
        return 'In Bearbeitung';
      case 'waiting':
        return 'Wartend';
      case 'resolved':
        return 'Gelöst';
      case 'closed':
        return 'Geschlossen';
      default:
        return status || '-';
    }
  };

  if (isLoading) {
    return (
      <Card>
        <div className="text-center py-8">
          <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          <p className={clsx('mt-4', adminMuted(isDark))}>Laden...</p>
        </div>
      </Card>
    );
  }

  if (tickets.length === 0) {
    return (
      <Card>
        <div className="text-center py-8">
          <svg
            className={clsx('w-12 h-12 mx-auto mb-4', isDark ? 'text-slate-600' : 'text-gray-300')}
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
          <p className={clsx(adminMuted(isDark))}>Keine aktiven Tickets</p>
          <p className={clsx('text-sm mt-2', adminCaption(isDark))}>Alle Tickets wurden bearbeitet</p>
        </div>
      </Card>
    );
  }

  return (
    <Card padding="none">
      <div
        className={clsx(
          'flex flex-wrap items-center justify-between gap-4 p-6 border-b',
          isDark ? 'border-slate-600' : 'border-gray-200',
        )}
      >
        <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
          Aktuelle Tickets
        </h2>
        <button
          type="button"
          onClick={() => navigate('/csr/tickets')}
          className={clsx(
            'text-sm hover:underline',
            isDark ? 'text-sky-400 hover:text-sky-300' : 'text-fin1-primary',
          )}
        >
          Alle anzeigen
        </button>
      </div>

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
            {pagedTickets.map((ticket, index) => (
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
                  <p className={clsx('text-sm', tableBodyCellPrimaryClasses(isDark))}>{ticket.subject}</p>
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
                <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                  {ticket.userEmail || ticket.userId}
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
        total={listTotal}
        itemLabel="Tickets"
        isDark={isDark}
        onPageChange={setPage}
      />
    </Card>
  );
}
