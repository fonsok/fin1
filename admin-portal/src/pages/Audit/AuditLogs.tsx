import { useCallback, useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { getAuditLogs } from '../../api/admin';
import { Card, Button, Badge, Input, PaginationBar } from '../../components/ui';
import { SortableTh, nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { formatDateTime } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMonoHintClasses,
  tableBodyCellMutedClasses,
  tableBodyCellPrimaryClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';
import { useDebounce } from '../../hooks/useDebounce';

export function AuditLogsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [logTypeFilter, setLogTypeFilter] = useState<string>('');
  const [actionFilter, setActionFilter] = useState<string>('');
  const [userIdFilter, setUserIdFilter] = useState<string>('');
  const debouncedAction = useDebounce(actionFilter);
  const debouncedUserId = useDebounce(userIdFilter);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(100);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  useEffect(() => { setPage(0); }, [debouncedAction, debouncedUserId]);

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['auditLogs', logTypeFilter, debouncedAction, debouncedUserId, page, pageSize, sortBy, sortOrder],
    queryFn: () =>
      getAuditLogs({
        logType: logTypeFilter || undefined,
        action: debouncedAction || undefined,
        userId: debouncedUserId || undefined,
        limit: pageSize,
        skip: page * pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
  });

  const onSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sortBy, sortOrder);
      setSortBy(next.sortBy);
      setSortOrder(next.sortOrder);
      setPage(0);
    },
    [sortBy, sortOrder],
  );

  const total = data?.total ?? 0;

  const getLogTypeVariant = (type: string): 'success' | 'warning' | 'danger' | 'info' | 'neutral' => {
    switch (type?.toLowerCase()) {
      case 'security': return 'danger';
      case 'compliance': return 'warning';
      case 'admin': return 'info';
      case 'admin_customer_view': return 'info';
      case 'user': return 'neutral';
      default: return 'neutral';
    }
  };

  const getLogTypeLabel = (type: string): string => {
    const labels: Record<string, string> = {
      'security': 'Sicherheit',
      'compliance': 'Compliance',
      'admin': 'Admin',
      'user': 'Benutzer',
      'system': 'System',
      'audit': 'Audit',
      'admin_customer_view': 'Kundensicht (Portal)',
    };
    return labels[type?.toLowerCase()] || type || '-';
  };

  const getActionLabel = (action: string): string => {
    const labels: Record<string, string> = {
      'login': 'Anmeldung',
      'logout': 'Abmeldung',
      'user_created': 'Benutzer erstellt',
      'user_updated': 'Benutzer aktualisiert',
      'user_deleted': 'Benutzer gelöscht',
      'status_changed': 'Status geändert',
      'permission_check': 'Berechtigungsprüfung',
      '2fa_enabled': '2FA aktiviert',
      '2fa_disabled': '2FA deaktiviert',
      '2fa_totp_success': '2FA erfolgreich',
      '2fa_verification_failed': '2FA fehlgeschlagen',
      'password_changed': 'Passwort geändert',
      'password_reset': 'Passwort zurückgesetzt',
      'terminate_user_sessions': 'Sessions beendet',
      'view_customer_record': 'Kundensicht geöffnet',
      'approved': 'Genehmigt',
      'rejected': 'Abgelehnt',
    };
    return labels[action] || action || '-';
  };

  return (
    <div className="space-y-6">
      {/* Filters */}
      <Card>
        <div className="flex flex-col sm:flex-row gap-4">
          <select
            value={logTypeFilter}
            onChange={(e) => {
              setLogTypeFilter(e.target.value);
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
            )}
          >
            <option value="">Alle Typen</option>
            <option value="security">Sicherheit</option>
            <option value="compliance">Compliance</option>
            <option value="admin">Admin</option>
            <option value="user">Benutzer</option>
            <option value="system">System</option>
            <option value="admin_customer_view">Kundensicht (Portal)</option>
          </select>

          <div className="flex-1">
            <Input
              placeholder="Aktion suchen..."
              value={actionFilter}
              onChange={(e) => setActionFilter(e.target.value)}
            />
          </div>

          <div className="flex-1">
            <Input
              placeholder="User-ID..."
              value={userIdFilter}
              onChange={(e) => setUserIdFilter(e.target.value)}
            />
          </div>

          <select
            value={pageSize}
            onChange={(e) => {
              setPageSize(Number(e.target.value));
              setPage(0);
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
            )}
          >
            <option value={100}>100 / Seite</option>
            <option value={250}>250 / Seite</option>
            <option value={500}>500 / Seite</option>
          </select>

          <Button variant="secondary" onClick={() => refetch()}>
            Suchen
          </Button>
        </div>
      </Card>

      {/* Results */}
      <Card padding="none">
        {isLoading ? (
          <div className="p-8 text-center">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className={clsx('mt-4', isDark ? 'text-slate-400' : 'text-gray-500')}>Laden...</p>
          </div>
        ) : error ? (
          <div className="p-8 text-center">
            <p className={clsx(isDark ? 'text-red-400' : 'text-red-500')}>Fehler beim Laden der Logs</p>
          </div>
        ) : !data?.logs?.length ? (
          <div className="p-8 text-center">
            <svg
              className={clsx('w-12 h-12 mx-auto mb-4', isDark ? 'text-slate-600' : 'text-gray-300')}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <p className={clsx(isDark ? 'text-slate-400' : 'text-gray-500')}>Keine Audit-Logs gefunden</p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className={tableTheadSurfaceClasses(isDark)}>
                  <tr>
                    <SortableTh
                      label="Zeitstempel"
                      field="createdAt"
                      sortBy={sortBy}
                      sortOrder={sortOrder}
                      onSort={onSort}
                      className={clsx('px-6 py-3', tableHeaderCellTextClasses(isDark))}
                    />
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Typ
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Aktion
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Benutzer
                    </th>
                    <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                      Ressource
                    </th>
                  </tr>
                </thead>
                <tbody className={tableBodyDivideClasses(isDark)}>
                  {data.logs.map((log, index: number) => (
                    <tr key={log.objectId} className={listRowStripeClasses(isDark, index)}>
                      <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                        {formatDateTime(log.createdAt)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <Badge variant={getLogTypeVariant(log.logType)}>
                          {getLogTypeLabel(log.logType)}
                        </Badge>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={clsx('text-sm', tableBodyCellPrimaryClasses(isDark))}>
                          {getActionLabel(log.action)}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <p className={clsx('text-sm', tableBodyCellPrimaryClasses(isDark))}>
                          {log.userEmail || log.userId || '-'}
                        </p>
                        {log.userRole && (
                          <p className={clsx('text-xs', tableBodyCellMutedClasses(isDark))}>{log.userRole}</p>
                        )}
                      </td>
                      <td className={clsx('px-6 py-4 whitespace-nowrap text-sm', tableBodyCellMutedClasses(isDark))}>
                        {log.resourceType ? (
                          <span>
                            {log.resourceType}
                            {log.resourceId && (
                              <span className={clsx('font-mono text-xs ml-1', tableBodyCellMonoHintClasses(isDark))}>
                                ({log.resourceId.slice(0, 8)}...)
                              </span>
                            )}
                          </span>
                        ) : (
                          '-'
                        )}
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
              itemLabel="Einträgen"
              isDark={isDark}
              onPageChange={setPage}
            />
          </>
        )}
      </Card>
    </div>
  );
}
