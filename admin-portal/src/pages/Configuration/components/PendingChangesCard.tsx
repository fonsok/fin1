import clsx from 'clsx';
import { Card, Badge } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import type { PendingConfigChange, ConfigurationParameter } from '../types';
import {
  COMMISSION_RATE_BUNDLE_DISPLAY_NAME,
  COMMISSION_RATE_BUNDLE_PARAMETER_NAME,
  formatCommissionRatesSummary,
} from '../commissionRateTraderApp';
import { adminCaption, adminMuted, adminPrimary, adminSoft } from '../../../utils/adminThemeClasses';

interface PendingChangesCardProps {
  requests: PendingConfigChange[];
  parameterDefinitions: Record<string, Omit<ConfigurationParameter, 'value'>>;
  formatValue: (key: string, value: number | string | boolean) => string;
}

function formatPendingChangeValue(
  parameterName: string,
  value: PendingConfigChange['oldValue'],
  formatValue: (key: string, value: number | string | boolean) => string,
): string {
  if (parameterName === COMMISSION_RATE_BUNDLE_PARAMETER_NAME && value && typeof value === 'object') {
    return formatCommissionRatesSummary({
      investorCommissionRateTotal: Number(value.investorCommissionRateTotal),
      traderCommissionRate: Number(value.traderCommissionRate),
      appCommissionRate: Number(value.appCommissionRate),
    });
  }
  return formatValue(parameterName, value as number | string | boolean);
}

function getPendingDisplayName(
  parameterName: string,
  parameterDefinitions: Record<string, Omit<ConfigurationParameter, 'value'>>,
): string {
  if (parameterName === COMMISSION_RATE_BUNDLE_PARAMETER_NAME) {
    return COMMISSION_RATE_BUNDLE_DISPLAY_NAME;
  }
  return parameterDefinitions[parameterName]?.displayName || parameterName;
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
                  {getPendingDisplayName(change.parameterName, parameterDefinitions)}
                </p>
                <p className={clsx('text-sm mt-1', adminSoft(isDark))}>
                  {formatPendingChangeValue(change.parameterName, change.oldValue, formatValue)}
                  {' -> '}
                  {formatPendingChangeValue(change.parameterName, change.newValue, formatValue)}
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
