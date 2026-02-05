import { Card, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import type { FailedLogin, SecurityAlert } from '../types';
import { getSeverityVariant } from '../utils';

interface OverviewTabProps {
  failedLogins: FailedLogin[];
  alerts: SecurityAlert[];
}

export function OverviewTab({ failedLogins, alerts }: OverviewTabProps): JSX.Element {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Recent Failed Logins */}
      <Card>
        <div className="p-4 border-b border-gray-100">
          <h2 className="text-lg font-semibold">Letzte fehlgeschlagene Logins</h2>
        </div>
        <div className="divide-y divide-gray-100">
          {failedLogins.slice(0, 5).map((login) => (
            <div key={login.objectId} className="p-4">
              <div className="flex items-center justify-between">
                <span className="font-medium text-gray-900">{login.email}</span>
                <span className="text-sm text-gray-500">{formatDateTime(login.timestamp)}</span>
              </div>
              <p className="text-sm text-gray-500 mt-1">
                IP: {login.ipAddress} • {login.reason}
              </p>
            </div>
          ))}
        </div>
      </Card>

      {/* Security Alerts */}
      <Card>
        <div className="p-4 border-b border-gray-100">
          <h2 className="text-lg font-semibold">Aktuelle Warnungen</h2>
        </div>
        <div className="divide-y divide-gray-100">
          {alerts
            .filter((a) => !a.reviewed)
            .slice(0, 5)
            .map((alert) => (
              <div key={alert.objectId} className="p-4">
                <div className="flex items-center gap-2 mb-1">
                  <Badge variant={getSeverityVariant(alert.severity)}>
                    {alert.severity.toUpperCase()}
                  </Badge>
                  <span className="text-sm text-gray-500">{formatDateTime(alert.createdAt)}</span>
                </div>
                <p className="text-sm text-gray-900">{alert.message}</p>
              </div>
            ))}
          {alerts.filter((a) => !a.reviewed).length === 0 && (
            <div className="p-8 text-center text-gray-500">Keine ungeprüften Warnungen</div>
          )}
        </div>
      </Card>
    </div>
  );
}
