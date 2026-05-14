import clsx from 'clsx';
import { Card, Button } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';

import { adminBodyStrong, adminCaption, adminEmphasisSoft, adminHeadline, adminLabel, adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
interface ApprovalRequestLike {
  objectId: string;
  requestType: string;
  requesterId: string;
  requesterEmail?: string;
  metadata?: Record<string, unknown>;
  createdAt: string;
}

interface ApprovalDecisionModalProps {
  selectedRequest: ApprovalRequestLike | null;
  actionType: 'approve' | 'reject' | null;
  notes: string;
  loading: boolean;
  onChangeNotes: (value: string) => void;
  onClose: () => void;
  onConfirm: () => void;
  getRequestTypeLabel: (type: string) => string;
  getParamDisplayName: (name: string) => string;
  formatConfigValue: (param: string, value: unknown) => string;
}

export function ApprovalDecisionModal({
  selectedRequest,
  actionType,
  notes,
  loading,
  onChangeNotes,
  onClose,
  onConfirm,
  getRequestTypeLabel,
  getParamDisplayName,
  formatConfigValue,
}: ApprovalDecisionModalProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (!selectedRequest || !actionType) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="w-full max-w-lg">
        <h3 className="text-lg font-semibold mb-4">
          {actionType === 'approve' ? 'Anfrage genehmigen' : 'Anfrage ablehnen'}
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
              {getRequestTypeLabel(selectedRequest.requestType)}
            </span>
          </div>
          <div className="flex justify-between gap-3">
            <span className={clsx('text-sm shrink-0', adminMuted(isDark))}>Beantragt von:</span>
            <span className={clsx('text-sm text-right break-all', adminBodyStrong(isDark))}>
              {selectedRequest.requesterEmail || selectedRequest.requesterId}
            </span>
          </div>
          <div className="flex justify-between gap-3">
            <span className={clsx('text-sm', adminMuted(isDark))}>Beantragt am:</span>
            <span className={clsx('text-sm', adminBodyStrong(isDark))}>
              {formatDateTime(selectedRequest.createdAt)}
            </span>
          </div>

          {(selectedRequest.requestType === 'configuration_change' || selectedRequest.requestType === 'config_change') && selectedRequest.metadata && (
            <div
              className={clsx(
                'mt-3 p-3 rounded-lg',
                isDark ? 'bg-slate-950/70 border border-slate-600' : 'bg-white border border-gray-200',
              )}
            >
              <p className={clsx('text-sm font-medium mb-2', adminHeadline(isDark))}>
                {getParamDisplayName(selectedRequest.metadata.parameterName as string)}
              </p>
              <div className="flex items-center gap-4 justify-center">
                <div className="text-center min-w-0 flex-1">
                  <p className={clsx('text-xs mb-1', adminMuted(isDark))}>Aktuell</p>
                  <p className={clsx('text-base font-semibold', adminHeadline(isDark))}>
                    {formatConfigValue(selectedRequest.metadata.parameterName as string, selectedRequest.metadata.oldValue)}
                  </p>
                </div>
                <svg
                  className={clsx('w-6 h-6 flex-shrink-0', adminCaption(isDark))}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
                <div className="text-center min-w-0 flex-1">
                  <p className={clsx('text-xs mb-1', adminMuted(isDark))}>Neuer Wert</p>
                  <p className="text-base font-semibold text-fin1-primary">
                    {formatConfigValue(selectedRequest.metadata.parameterName as string, selectedRequest.metadata.newValue)}
                  </p>
                </div>
              </div>
            </div>
          )}
          {typeof selectedRequest.metadata?.reason === 'string' && selectedRequest.metadata.reason && (
            <div className="mt-2">
              <span className={clsx('text-sm', adminMuted(isDark))}>Begründung:</span>
              <p className={clsx('text-sm mt-1', adminEmphasisSoft(isDark))}>{selectedRequest.metadata.reason}</p>
            </div>
          )}
        </div>

        <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
          {actionType === 'approve' ? 'Notizen (optional)' : 'Ablehnungsgrund (erforderlich)'}
        </label>
        <textarea
          value={notes}
          onChange={(e) => onChangeNotes(e.target.value)}
          className={clsx(
            'w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4',
            isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'border-gray-300 bg-white text-gray-900',
          )}
          rows={3}
          placeholder={actionType === 'approve' ? 'Optionale Notizen...' : 'Grund für die Ablehnung...'}
          required={actionType === 'reject'}
        />

        <div className="flex gap-3 justify-end">
          <Button variant="secondary" onClick={onClose}>
            Abbrechen
          </Button>
          <Button
            variant={actionType === 'approve' ? 'success' : 'danger'}
            loading={loading}
            disabled={actionType === 'reject' && !notes.trim()}
            onClick={onConfirm}
          >
            {actionType === 'approve' ? 'Genehmigen' : 'Ablehnen'}
          </Button>
        </div>
      </Card>
    </div>
  );
}
