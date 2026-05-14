import clsx from 'clsx';
import { Card, Button } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';

import { adminBodyStrong, adminHeadline, adminLabel, adminMuted, adminPrimary, adminSoft } from '../../../utils/adminThemeClasses';
interface ApprovalRequestLike {
  objectId: string;
  requestType: string;
  metadata?: Record<string, unknown>;
  createdAt: string;
}

interface WithdrawRequestModalProps {
  withdrawTarget: ApprovalRequestLike | null;
  notes: string;
  loading: boolean;
  onChangeNotes: (value: string) => void;
  onClose: () => void;
  onConfirm: () => void;
  getRequestTypeLabel: (type: string) => string;
  getParamDisplayName: (name: string) => string;
  formatConfigValue: (param: string, value: unknown) => string;
}

export function WithdrawRequestModal({
  withdrawTarget,
  notes,
  loading,
  onChangeNotes,
  onClose,
  onConfirm,
  getRequestTypeLabel,
  getParamDisplayName,
  formatConfigValue,
}: WithdrawRequestModalProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (!withdrawTarget) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="w-full max-w-lg">
        <h3 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>
          Antrag zurückziehen
        </h3>

        <div
          className={clsx(
            'space-y-3 mb-4 p-4 rounded-lg',
            isDark ? 'bg-slate-900/50 border border-slate-600' : 'bg-gray-50',
          )}
        >
          <div className="flex justify-between gap-3">
            <span className={clsx('text-sm', adminMuted(isDark))}>Typ:</span>
            <span className={clsx('text-sm font-medium text-right', adminPrimary(isDark))}>
              {getRequestTypeLabel(withdrawTarget.requestType)}
            </span>
          </div>
          <div className="flex justify-between gap-3">
            <span className={clsx('text-sm', adminMuted(isDark))}>Beantragt am:</span>
            <span className={clsx('text-sm', adminBodyStrong(isDark))}>
              {formatDateTime(withdrawTarget.createdAt)}
            </span>
          </div>
          {(withdrawTarget.requestType === 'configuration_change' || withdrawTarget.requestType === 'config_change') && withdrawTarget.metadata && (
            <div
              className={clsx(
                'mt-2 p-3 rounded-lg',
                isDark ? 'bg-slate-950/70 border border-slate-600' : 'bg-white border border-gray-200',
              )}
            >
              <p className={clsx('text-sm font-medium mb-1', adminHeadline(isDark))}>
                {getParamDisplayName(withdrawTarget.metadata.parameterName as string)}
              </p>
              <p className={clsx('text-sm', adminSoft(isDark))}>
                {formatConfigValue(withdrawTarget.metadata.parameterName as string, withdrawTarget.metadata.oldValue)}
                {' → '}
                <span className="font-semibold text-fin1-primary">
                  {formatConfigValue(withdrawTarget.metadata.parameterName as string, withdrawTarget.metadata.newValue)}
                </span>
              </p>
            </div>
          )}
        </div>

        <p className={clsx('text-sm mb-3', adminSoft(isDark))}>
          Möchten Sie diesen Antrag wirklich zurückziehen? Diese Aktion kann nicht rückgängig gemacht werden.
        </p>

        <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
          Grund (optional)
        </label>
        <textarea
          value={notes}
          onChange={(e) => onChangeNotes(e.target.value)}
          className={clsx(
            'w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4',
            isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'border-gray-300 bg-white text-gray-900',
          )}
          rows={2}
          placeholder="Grund für das Zurückziehen..."
        />

        <div className="flex gap-3 justify-end">
          <Button variant="secondary" onClick={onClose}>
            Abbrechen
          </Button>
          <Button variant="danger" loading={loading} onClick={onConfirm}>
            Zurückziehen
          </Button>
        </div>
      </Card>
    </div>
  );
}
