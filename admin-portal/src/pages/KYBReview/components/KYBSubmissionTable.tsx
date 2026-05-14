import { Badge } from '../../../components/ui';
import { Button } from '../../../components/ui';
import { SortableTh, type SortOrder } from '../../../components/table/SortableTh';
import { useTheme } from '../../../context/ThemeContext';
import { formatDateTime } from '../../../utils/format';
import { listRowStripeClasses, tableBodyDivideClasses } from '../../../utils/tableStriping';
import type { KybSubmission } from '../../../api/admin';
import clsx from 'clsx';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
const KYB_STATUS_CONFIG: Record<string, { label: string; variant: 'success' | 'warning' | 'danger' | 'info' | 'neutral' }> = {
  pending_review: { label: 'Ausstehend', variant: 'warning' },
  more_info_requested: { label: 'Nachbesserung', variant: 'warning' },
  approved: { label: 'Genehmigt', variant: 'success' },
  rejected: { label: 'Abgelehnt', variant: 'danger' },
  draft: { label: 'Entwurf', variant: 'neutral' },
};

interface KYBSubmissionTableProps {
  submissions: KybSubmission[];
  onViewDetail: (userId: string) => void;
  onReview: (submission: KybSubmission) => void;
  showActions: boolean;
  /** Ohne reviewCompanyKyb nur Details, kein „Prüfen“. */
  canReview?: boolean;
  sortBy: string;
  sortOrder: SortOrder;
  onSort: (field: string) => void;
}

export function KYBSubmissionTable({
  submissions,
  onViewDetail,
  onReview,
  showActions,
  canReview = true,
  sortBy,
  sortOrder,
  onSort,
}: KYBSubmissionTableProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className={clsx(
            'text-left',
            isDark ? 'text-slate-400 border-b border-slate-600' : 'text-gray-500 border-b border-gray-200',
          )}>
            <th className="pb-3 pr-4 font-medium">Kunden-ID</th>
            <SortableTh
              label="Name"
              field="lastName"
              sortBy={sortBy}
              sortOrder={sortOrder}
              onSort={onSort}
              className="pb-3 pr-4 font-medium normal-case tracking-normal"
              buttonClassName="normal-case font-medium"
            />
            <th className="pb-3 pr-4 font-medium">E-Mail</th>
            <th className="pb-3 pr-4 font-medium">Status</th>
            <SortableTh
              label="Eingereicht am"
              field="companyKybCompletedAt"
              sortBy={sortBy}
              sortOrder={sortOrder}
              onSort={onSort}
              className="pb-3 pr-4 font-medium normal-case tracking-normal"
              buttonClassName="normal-case font-medium"
            />
            <th className="pb-3 font-medium text-right">Aktionen</th>
          </tr>
        </thead>
        <tbody className={tableBodyDivideClasses(isDark)}>
          {submissions.map((s, index) => {
            const statusCfg = KYB_STATUS_CONFIG[s.companyKybStatus] ?? { label: s.companyKybStatus, variant: 'neutral' as const };
            const displayName = [s.firstName, s.lastName].filter(Boolean).join(' ') || '-';

            return (
              <tr
                key={s.userId}
                className={listRowStripeClasses(isDark, index, { className: 'transition-colors cursor-pointer' })}
                onClick={() => onViewDetail(s.userId)}
              >
                <td className={clsx('py-3 pr-4 font-mono text-xs', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  {s.customerNumber}
                </td>
                <td className={clsx('py-3 pr-4 font-medium', adminPrimary(isDark))}>
                  {displayName}
                </td>
                <td className={clsx('py-3 pr-4', isDark ? 'text-slate-300' : 'text-gray-600')}>
                  {s.email}
                </td>
                <td className="py-3 pr-4">
                  <Badge variant={statusCfg.variant}>{statusCfg.label}</Badge>
                </td>
                <td className={clsx('py-3 pr-4', adminMuted(isDark))}>
                  {formatDateTime(s.companyKybCompletedAt)}
                </td>
                <td className="py-3 text-right">
                  <div className="flex items-center justify-end gap-2" onClick={(e) => e.stopPropagation()}>
                    <Button variant="ghost" size="sm" onClick={() => onViewDetail(s.userId)}>
                      Details
                    </Button>
                    {showActions && canReview && (
                      <Button variant="primary" size="sm" onClick={() => onReview(s)}>
                        Prüfen
                      </Button>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
