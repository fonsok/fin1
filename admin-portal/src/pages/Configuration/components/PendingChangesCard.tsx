import clsx from 'clsx';
import { Card, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
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
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (!requests.length) return null;

  return (
    <Card>
      <h3 className={clsx('text-md font-semibold mb-4', isDark ? 'text-slate-100' : 'text-gray-900')}>
        Ausstehende Änderungen
      </h3>
      <div className="space-y-3">
        {requests.map((change) => (
          <div
            key={change.id}
            className={clsx(
              'p-4 border rounded-lg',
              isDark ? 'bg-amber-950/25 border-amber-800/70' : 'bg-yellow-50 border-yellow-200',
            )}
          >
            <div className="flex justify-between items-start">
              <div>
                <p className={clsx('font-medium', isDark ? 'text-slate-100' : 'text-gray-900')}>
                  {parameterDefinitions[change.parameterName]?.displayName || change.parameterName}
                </p>
                <p className={clsx('text-sm mt-1', isDark ? 'text-slate-300' : 'text-gray-600')}>
                  {formatValue(change.parameterName, change.oldValue)}
                  {' -> '}
                  {formatValue(change.parameterName, change.newValue)}
                </p>
                <p className={clsx('text-sm mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
                  Grund: {change.reason}
                </p>
                <p className={clsx('text-xs mt-2', isDark ? 'text-slate-500' : 'text-gray-400')}>
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
