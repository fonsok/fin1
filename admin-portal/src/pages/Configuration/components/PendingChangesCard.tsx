import { Card, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import type { PendingConfigChange, ConfigurationParameter } from '../types';

interface PendingChangesCardProps {
  requests: PendingConfigChange[];
  parameterDefinitions: Record<string, Omit<ConfigurationParameter, 'value'>>;
  formatValue: (key: string, value: number | string | boolean) => string;
}

export function PendingChangesCard({
  requests,
  parameterDefinitions,
  formatValue,
}: PendingChangesCardProps) {
  if (!requests.length) return null;

  return (
    <Card>
      <h3 className="text-md font-semibold mb-4">Ausstehende Änderungen</h3>
      <div className="space-y-3">
        {requests.map((change) => (
          <div key={change.id} className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
            <div className="flex justify-between items-start">
              <div>
                <p className="font-medium">
                  {parameterDefinitions[change.parameterName]?.displayName || change.parameterName}
                </p>
                <p className="text-sm text-gray-600 mt-1">
                  {formatValue(change.parameterName, change.oldValue)}
                  {' -> '}
                  {formatValue(change.parameterName, change.newValue)}
                </p>
                <p className="text-sm text-gray-500 mt-1">Grund: {change.reason}</p>
                <p className="text-xs text-gray-400 mt-2">
                  Von: {change.requesterEmail} - {formatDateTime(change.createdAt)}
                </p>
              </div>
              <Badge variant="warning">Ausstehend</Badge>
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}
