import { Card, Button, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import type { SecurityAlert } from '../types';
import { getSeverityVariant } from '../utils';

interface AlertsTabProps {
  alerts: SecurityAlert[];
}

export function AlertsTab({ alerts }: AlertsTabProps): JSX.Element {
  return (
    <Card>
      <div className="divide-y divide-gray-100">
        {alerts.map((alert) => (
          <div key={alert.objectId} className={`p-4 ${alert.reviewed ? 'opacity-60' : ''}`}>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <Badge variant={getSeverityVariant(alert.severity)}>{alert.severity.toUpperCase()}</Badge>
                <span className="text-sm font-medium text-gray-700">
                  {alert.type.replace('_', ' ').toUpperCase()}
                </span>
                {alert.reviewed && <Badge variant="neutral">Geprüft</Badge>}
              </div>
              <span className="text-sm text-gray-500">{formatDateTime(alert.createdAt)}</span>
            </div>
            <p className="text-gray-900">{alert.message}</p>
            {alert.email && <p className="text-sm text-gray-500 mt-1">Benutzer: {alert.email}</p>}
            {!alert.reviewed && (
              <div className="mt-3">
                <Button variant="ghost" size="sm">Als geprüft markieren</Button>
              </div>
            )}
          </div>
        ))}
      </div>
    </Card>
  );
}
