import clsx from 'clsx';
import { Button } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime, formatRelative } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';

interface ApprovalRequestLike {
  objectId: string;
  requestType: string;
  requesterId: string;
  requesterEmail?: string;
  requesterRole: string;
  status: string;
  approverEmail?: string;
  approverNotes?: string;
  rejectionReason?: string;
  withdrawnReason?: string;
  updatedAt: string;
  createdAt: string;
  expiresAt: string;
  metadata?: Record<string, unknown>;
}

interface ApprovalsRequestTableProps {
  requests: ApprovalRequestLike[];
  showActions?: boolean;
  showStatus?: boolean;
  showDecision?: boolean;
  showWithdraw?: boolean;
  onApprove?: (r: ApprovalRequestLike) => void;
  onReject?: (r: ApprovalRequestLike) => void;
  onWithdraw?: (r: ApprovalRequestLike) => void;
  currentUserId?: string;
  getRequestTypeLabel: (type: string) => string;
  getStatusBadge: (status: string) => JSX.Element;
  renderRequestDetails: (request: ApprovalRequestLike) => JSX.Element;
}

function requesterIdString(r: ApprovalRequestLike): string {
  const id = r.requesterId;
  if (typeof id === 'string') return id;
  if (id && typeof id === 'object' && 'objectId' in id) return (id as { objectId: string }).objectId;
  return String(id ?? '');
}

export function ApprovalsRequestTable({
  requests,
  showActions,
  showStatus,
  showDecision,
  showWithdraw,
  onApprove,
  onReject,
  onWithdraw,
  currentUserId,
  getRequestTypeLabel,
  getStatusBadge,
  renderRequestDetails,
}: ApprovalsRequestTableProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const hasActionColumn = showActions || showWithdraw;

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead className={tableTheadSurfaceClasses(isDark)}>
          <tr>
            <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
              Typ
            </th>
            <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
              Beantragt von
            </th>
            <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
              Details
            </th>
            <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
              Datum
            </th>
            {showStatus && (
              <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                Status
              </th>
            )}
            {showDecision && (
              <th className={clsx('px-6 py-3 text-left text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                Entscheidung
              </th>
            )}
            {hasActionColumn && (
              <th className={clsx('px-6 py-3 text-right text-xs font-medium uppercase tracking-wider', tableHeaderCellTextClasses(isDark))}>
                Aktionen
              </th>
            )}
          </tr>
        </thead>
        <tbody className={tableBodyDivideClasses(isDark)}>
          {requests.map((request, index) => {
            const isOwn = currentUserId != null && requesterIdString(request) === currentUserId;
            const canWithdraw = showWithdraw && isOwn && request.status === 'pending';
            const canApproveReject = showActions && !isOwn;

            return (
              <tr key={request.objectId} className={listRowStripeClasses(isDark, index)}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span
                    className={clsx(
                      'text-sm font-medium',
                      isDark ? 'text-slate-100' : 'text-gray-900',
                    )}
                  >
                    {getRequestTypeLabel(request.requestType)}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <p className={clsx('text-sm', isDark ? 'text-slate-100' : 'text-gray-900')}>
                    {request.requesterEmail || requesterIdString(request)}
                    {isOwn && (
                      <span className={clsx('ml-1 text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                        (Sie)
                      </span>
                    )}
                  </p>
                  <p className={clsx('text-xs', isDark ? 'text-slate-400' : 'text-gray-500')}>
                    {request.requesterRole}
                  </p>
                </td>
                <td className="px-6 py-4">
                  {renderRequestDetails(request)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <p className={clsx('text-sm', isDark ? 'text-slate-100' : 'text-gray-900')}>
                    {formatDateTime(request.createdAt)}
                  </p>
                  <p className={clsx('text-xs', isDark ? 'text-slate-400' : 'text-gray-500')}>
                    {formatRelative(request.createdAt)}
                  </p>
                </td>
                {showStatus && (
                  <td className="px-6 py-4 whitespace-nowrap">
                    {getStatusBadge(request.status)}
                  </td>
                )}
                {showDecision && (
                  <td className="px-6 py-4">
                    <div className="text-sm">
                      {request.approverEmail && (
                        <p className={clsx(isDark ? 'text-slate-300' : 'text-gray-600')}>{request.approverEmail}</p>
                      )}
                      {request.approverNotes && (
                        <p
                          className={clsx(
                            'text-xs truncate max-w-xs',
                            isDark ? 'text-slate-400' : 'text-gray-500',
                          )}
                        >
                          {request.approverNotes}
                        </p>
                      )}
                      {request.rejectionReason && (
                        <p className="text-xs text-red-600 truncate max-w-xs">{request.rejectionReason}</p>
                      )}
                      {request.withdrawnReason && (
                        <p
                          className={clsx(
                            'text-xs truncate max-w-xs',
                            isDark ? 'text-sky-300' : 'text-blue-600',
                          )}
                        >
                          {request.withdrawnReason}
                        </p>
                      )}
                      {request.updatedAt && request.status !== 'pending' && (
                        <p className={clsx('text-xs', isDark ? 'text-slate-500' : 'text-gray-400')}>
                          {formatDateTime(request.updatedAt)}
                        </p>
                      )}
                    </div>
                  </td>
                )}
                {hasActionColumn && (
                  <td className="px-6 py-4 whitespace-nowrap text-right">
                    <div className="flex gap-2 justify-end">
                      {canApproveReject && (
                        <>
                          <Button variant="success" size="sm" onClick={() => onApprove?.(request)}>
                            Genehmigen
                          </Button>
                          <Button variant="danger" size="sm" onClick={() => onReject?.(request)}>
                            Ablehnen
                          </Button>
                        </>
                      )}
                      {canWithdraw && (
                        <Button variant="secondary" size="sm" onClick={() => onWithdraw?.(request)}>
                          Zurückziehen
                        </Button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
