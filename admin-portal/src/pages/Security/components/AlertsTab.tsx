import clsx from 'clsx';
import { Card, Button, Badge } from '../../../components/ui';
import { SortChip, type SortOrder } from '../../../components/table/SortableTh';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { SecurityAlert } from '../types';
import { getSeverityVariant } from '../utils';
import { adminBorderChrome } from '../../../utils/adminThemeClasses';

interface AlertsTabProps {
  alerts: SecurityAlert[];
  sortBy: string;
  sortOrder: SortOrder;
  onSort: (field: string) => void;
  isDark: boolean;
}

export function AlertsTab({ alerts, sortBy, sortOrder, onSort, isDark }: AlertsTabProps): JSX.Element {
  const { theme } = useTheme();
  const tabIsDark = theme === 'dark';
  const dark = isDark || tabIsDark;

  return (
    <Card>
      <div
        className={clsx(
          'flex flex-wrap items-center gap-2 px-3 py-2 border-b',
          adminBorderChrome(dark),
        )}
      >
        <span className={clsx('text-xs font-medium uppercase', dark ? 'text-slate-400' : 'text-gray-500')}>
          Sortierung
        </span>
        <SortChip label="Zeit" field="occurredAt" sortBy={sortBy} sortOrder={sortOrder} onSort={onSort} isDark={dark} />
        <SortChip label="Schwere" field="severity" sortBy={sortBy} sortOrder={sortOrder} onSort={onSort} isDark={dark} />
      </div>
      <div className="p-2 space-y-1">
        {alerts.map((alert, index) => (
          <div
            key={alert.objectId}
            className={clsx('p-4 rounded-lg', alert.reviewed && 'opacity-60', listRowStripeClasses(dark, index))}
          >
            <div className="flex items-center justify-between mb-2 gap-2 flex-wrap">
              <div className="flex items-center gap-2 flex-wrap">
                <Badge variant={getSeverityVariant(alert.severity)}>{alert.severity.toUpperCase()}</Badge>
                <span className={clsx('text-sm font-medium', dark ? 'text-slate-200' : 'text-gray-700')}>
                  {alert.type.replace('_', ' ').toUpperCase()}
                </span>
                {alert.reviewed && <Badge variant="neutral">Geprüft</Badge>}
              </div>
              <span className={clsx('text-sm', dark ? 'text-slate-400' : 'text-gray-500')}>
                {formatDateTime(alert.createdAt)}
              </span>
            </div>
            <p className={clsx(dark ? 'text-slate-100' : 'text-gray-900')}>{alert.message}</p>
            {alert.email && (
              <p className={clsx('text-sm mt-1', dark ? 'text-slate-400' : 'text-gray-500')}>
                Benutzer: {alert.email}
              </p>
            )}
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
