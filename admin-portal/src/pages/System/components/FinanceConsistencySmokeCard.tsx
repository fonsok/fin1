import clsx from 'clsx';
import type { ReactNode } from 'react';
import { Badge, Card } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';

import { adminMuted, adminPrimary } from '../../../utils/adminThemeClasses';
type HealthStatus = 'healthy' | 'degraded' | 'down' | 'unknown';

export type FinanceConsistencySmokeStatus = {
  overall: HealthStatus;
  checkedAt: string;
  issues: string[];
  mirrorBasis?: { overall?: HealthStatus; hasSnapshot?: boolean; reason?: string };
  settlementConsistency?: { overall?: HealthStatus; checkedTrades?: number; checkedInvestments?: number; mismatchCount?: number };
  ledgerFuzzySmoke?: { fuzzyUserFilter?: string; sampledRows?: number; matches?: number; parseObjectIdFilterWouldApply?: boolean };
  referenceCoverage?: { checkedRows?: number; missingReferenceDocumentId?: number };
};

type Props = {
  isDark: boolean;
  financeSmoke: FinanceConsistencySmokeStatus;
  financeSmokeLoading: boolean;
  renderStatusBadge: (status: HealthStatus) => ReactNode;
};

export function FinanceConsistencySmokeCard({
  isDark,
  financeSmoke,
  financeSmokeLoading,
  renderStatusBadge,
}: Props) {
  return (
    <Card className={clsx('border', financeSmoke.overall === 'healthy'
      ? (isDark ? 'border-emerald-700 bg-emerald-950/20' : 'border-green-200 bg-green-50')
      : (isDark ? 'border-amber-700 bg-amber-950/20' : 'border-yellow-200 bg-yellow-50'))}>
      <div className="flex items-start justify-between gap-4 flex-col md:flex-row">
        <div>
          <h3 className={clsx('text-md font-semibold', adminPrimary(isDark))}>
            Finance Consistency Smoke
          </h3>
          <p className={clsx('text-sm mt-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
            Kompakter End-to-End Smoke fuer Ledger/Konten/Buchungen/User-Fuzzy/Belegkette.
          </p>
          <p className={clsx('text-xs mt-1', isDark ? 'text-slate-400' : 'text-gray-600')}>
            Letzte Pruefung: {formatDateTime(financeSmoke.checkedAt)}
          </p>
        </div>
        <div className="flex items-center gap-3">
          {financeSmokeLoading ? <Badge variant="neutral">Laedt…</Badge> : renderStatusBadge(financeSmoke.overall)}
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className={clsx('rounded-md border p-3', isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-white')}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Issues</p>
          <p
            className={clsx(
              'text-lg font-semibold',
              (financeSmoke.issues?.length || 0) === 0
                ? isDark
                  ? 'text-emerald-400'
                  : 'text-green-500'
                : isDark
                  ? 'text-amber-400'
                  : 'text-yellow-500',
            )}
          >
            {financeSmoke.issues?.length || 0}
          </p>
        </div>
        <div className={clsx('rounded-md border p-3', isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-white')}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Settlement Trades</p>
          <p className={clsx('text-lg font-semibold', adminPrimary(isDark))}>{financeSmoke.settlementConsistency?.checkedTrades ?? 0}</p>
        </div>
        <div className={clsx('rounded-md border p-3', isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-white')}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Ledger Fuzzy Matches</p>
          <p className={clsx('text-lg font-semibold', adminPrimary(isDark))}>{financeSmoke.ledgerFuzzySmoke?.matches ?? 0}</p>
        </div>
        <div className={clsx('rounded-md border p-3', isDark ? 'border-slate-700 bg-slate-900/40' : 'border-gray-200 bg-white')}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Missing Beleg-Refs</p>
          <p
            className={clsx(
              'text-lg font-semibold',
              (financeSmoke.referenceCoverage?.missingReferenceDocumentId || 0) === 0
                ? isDark
                  ? 'text-emerald-400'
                  : 'text-green-500'
                : isDark
                  ? 'text-red-400'
                  : 'text-red-500',
            )}
          >
            {financeSmoke.referenceCoverage?.missingReferenceDocumentId ?? 0}
          </p>
        </div>
      </div>

      {(financeSmoke.issues?.length || 0) > 0 && (
        <div className={clsx('mt-3 rounded-md border px-3 py-2 text-sm', isDark ? 'border-amber-700 bg-amber-950/30 text-amber-200' : 'border-yellow-300 bg-yellow-50 text-yellow-800')}>
          Issues: {financeSmoke.issues.join(', ')}
        </div>
      )}
    </Card>
  );
}
