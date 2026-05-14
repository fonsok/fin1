import clsx from 'clsx';
import { Card, Badge } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { FailedLogin, SecurityAlert } from '../types';
import { getSeverityVariant } from '../utils';

import { adminBorderChromeSoft, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface OverviewTabProps {
  failedLogins: FailedLogin[];
  alerts: SecurityAlert[];
}

export function OverviewTab({ failedLogins, alerts }: OverviewTabProps): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const unreviewedAlerts = alerts.filter((a) => !a.reviewed).slice(0, 5);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Recent Failed Logins */}
      <Card>
        <div className={clsx('p-4 border-b', adminBorderChromeSoft(isDark))}>
          <h2 className="text-lg font-semibold">Letzte fehlgeschlagene Logins</h2>
        </div>
        <div className="p-2 space-y-1">
          {failedLogins.slice(0, 5).map((login, index) => (
            <div key={login.objectId} className={clsx('p-3 rounded-lg', listRowStripeClasses(isDark, index))}>
              <div className="flex items-center justify-between gap-2">
                <span className={clsx('font-medium', adminPrimary(isDark))}>
                  {login.email}
                </span>
                <span className={clsx('text-sm shrink-0', adminMuted(isDark))}>
                  {formatDateTime(login.timestamp)}
                </span>
              </div>
              <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
                IP: {login.ipAddress} • {login.reason}
              </p>
            </div>
          ))}
        </div>
      </Card>

      {/* Security Alerts */}
      <Card>
        <div className={clsx('p-4 border-b', adminBorderChromeSoft(isDark))}>
          <h2 className="text-lg font-semibold">Aktuelle Warnungen</h2>
        </div>
        <div className="p-2 space-y-1">
          {unreviewedAlerts.map((alert, index) => (
            <div key={alert.objectId} className={clsx('p-3 rounded-lg', listRowStripeClasses(isDark, index))}>
              <div className="flex items-center gap-2 mb-1 flex-wrap">
                <Badge variant={getSeverityVariant(alert.severity)}>
                  {alert.severity.toUpperCase()}
                </Badge>
                <span className={clsx('text-sm', adminMuted(isDark))}>
                  {formatDateTime(alert.createdAt)}
                </span>
              </div>
              <p className={clsx('text-sm', adminPrimary(isDark))}>{alert.message}</p>
            </div>
          ))}
          {alerts.filter((a) => !a.reviewed).length === 0 && (
            <div className={clsx('p-8 text-center', adminMuted(isDark))}>
              Keine ungeprüften Warnungen
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}
