import clsx from 'clsx';
import { Card, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import type { PendingConfigChange, ConfigurationParameter } from '../types';

import { adminCaption, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
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
      <h3 className={clsx('text-md font-semibold mb-4', adminPrimary(isDark))}>
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
                <p className={clsx('font-medium', adminPrimary(isDark))}>
                  {parameterDefinitions[change.parameterName]?.displayName || change.parameterName}
                </p>
                <p className={clsx('text-sm mt-1', isDark ? 'text-slate-300' : 'text-gray-600')}>
                  {formatValue(change.parameterName, change.oldValue)}
                  {' -> '}
                  {formatValue(change.parameterName, change.newValue)}
                </p>
                <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
                  Grund: {change.reason}
                </p>
                <p className={clsx('text-xs mt-2', adminCaption(isDark))}>
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
