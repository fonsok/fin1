import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge, Input } from '../../components/ui';
import { formatDateTime } from '../../utils/format';

interface AuditLog {
  objectId: string;
  logType: string;
  action: string;
  userId: string;
  userEmail?: string;
  userRole?: string;
  resourceType?: string;
  resourceId?: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  createdAt: string;
}

export function AuditLogsPage() {
  const [logTypeFilter, setLogTypeFilter] = useState<string>('');
  const [actionFilter, setActionFilter] = useState<string>('');
  const [userIdFilter, setUserIdFilter] = useState<string>('');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['auditLogs', logTypeFilter, actionFilter, userIdFilter],
    queryFn: () => cloudFunction<{ logs: AuditLog[]; total: number }>('getAuditLogs', {
      logType: logTypeFilter || undefined,
      action: actionFilter || undefined,
      userId: userIdFilter || undefined,
      limit: 100,
    }),
  });

  const getLogTypeVariant = (type: string): 'success' | 'warning' | 'danger' | 'info' | 'neutral' => {
    switch (type?.toLowerCase()) {
      case 'security': return 'danger';
      case 'compliance': return 'warning';
      case 'admin': return 'info';
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
            onChange={(e) => setLogTypeFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
          >
            <option value="">Alle Typen</option>
            <option value="security">Sicherheit</option>
            <option value="compliance">Compliance</option>
            <option value="admin">Admin</option>
            <option value="user">Benutzer</option>
            <option value="system">System</option>
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
            <p className="text-gray-500 mt-4">Laden...</p>
          </div>
        ) : error ? (
          <div className="p-8 text-center">
            <p className="text-red-500">Fehler beim Laden der Logs</p>
          </div>
        ) : !data?.logs?.length ? (
          <div className="p-8 text-center">
            <svg className="w-12 h-12 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <p className="text-gray-500">Keine Audit-Logs gefunden</p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Zeitstempel
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Typ
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Aktion
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Benutzer
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Ressource
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {data.logs.map((log) => (
                    <tr key={log.objectId} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {formatDateTime(log.createdAt)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <Badge variant={getLogTypeVariant(log.logType)}>
                          {getLogTypeLabel(log.logType)}
                        </Badge>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-sm text-gray-900">
                          {getActionLabel(log.action)}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <p className="text-sm text-gray-900">
                          {log.userEmail || log.userId || '-'}
                        </p>
                        {log.userRole && (
                          <p className="text-xs text-gray-500">{log.userRole}</p>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {log.resourceType ? (
                          <span>
                            {log.resourceType}
                            {log.resourceId && (
                              <span className="font-mono text-xs ml-1">
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
            <div className="px-6 py-4 border-t border-gray-200">
              <p className="text-sm text-gray-500">
                Zeige {data.logs.length} von {data.total} Einträgen
              </p>
            </div>
          </>
        )}
      </Card>
    </div>
  );
}
