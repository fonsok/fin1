import clsx from 'clsx';
import { Badge } from '../../../components/ui';
import { formatCurrency, formatNumber } from '../../../utils/format';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import {
  adminBodyStrong,
  adminMonoHint,
  adminMuted,
  adminPrimary,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import type { SummaryReportPoolParticipation } from './types';

export function PoolParticipationsTable({
  participations,
  isDark,
}: {
  participations: SummaryReportPoolParticipation[];
  isDark: boolean;
}): JSX.Element {
  const thClass = clsx(
    'px-3 py-2 text-xs font-medium uppercase tracking-wide',
    adminMonoHint(isDark),
  );

  if (participations.length === 0) {
    return (
      <p className={clsx('text-sm', adminMuted(isDark))}>Keine PoolTradeParticipation.</p>
    );
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-transparent">
      <table className="w-full text-sm">
        <thead className={clsx(isDark ? 'bg-slate-800/90' : 'bg-sky-100')}>
          <tr>
            <th className={clsx(thClass, 'text-left')}>Investor</th>
            <th className={clsx(thClass, 'text-left')}>Investment</th>
            <th className={clsx(thClass, 'text-right')}>Anteil</th>
            <th className={clsx(thClass, 'text-right')}>Stück</th>
            <th className={clsx(thClass, 'text-right')}>Active @ Einstand</th>
            <th className={clsx(thClass, 'text-right')}>Residual</th>
            <th className={clsx(thClass, 'text-right')}>Gewinn-Anteil</th>
            <th className={clsx(thClass, 'text-center')}>Abgerechnet</th>
          </tr>
        </thead>
        <tbody className={clsx(isDark ? 'divide-y divide-slate-700' : 'divide-y divide-blue-100')}>
          {participations.map((p, idx) => (
            <tr
              key={p.investmentId || idx}
              className={listRowStripeClasses(isDark, idx, { hover: false })}
            >
              <td className="px-3 py-2">
                <p className={clsx('font-medium', adminPrimary(isDark))}>{p.investorName}</p>
                <p className={clsx('text-xs', adminMuted(isDark))}>{p.investorEmail}</p>
              </td>
              <td className={clsx('px-3 py-2 font-mono text-xs', adminMuted(isDark))}>
                {p.investmentNumber || p.investmentId.slice(0, 8)}
              </td>
              <td className={clsx('px-3 py-2 text-right font-mono', adminBodyStrong(isDark))}>
                {p.ownershipPercentage.toFixed(1)}%
              </td>
              <td className={clsx('px-3 py-2 text-right font-mono', adminBodyStrong(isDark))}>
                {(p.poolPieces ?? 0) > 0 ? formatNumber(p.poolPieces ?? 0) : '—'}
              </td>
              <td className={clsx('px-3 py-2 text-right', adminPrimary(isDark))}>
                {formatCurrency(p.activeInvestmentAtBid ?? 0)}
              </td>
              <td className={clsx('px-3 py-2 text-right font-mono text-xs', adminMuted(isDark))}>
                {(p.investmentResidual ?? 0) > 0
                  ? formatCurrency(p.investmentResidual ?? 0)
                  : '—'}
              </td>
              <td className={clsx('px-3 py-2 text-right', adminPrimary(isDark))}>
                {formatCurrency(p.profitShare)}
              </td>
              <td className="px-3 py-2 text-center">
                <Badge variant={p.isSettled ? 'success' : 'warning'}>
                  {p.isSettled ? 'Ja' : 'Offen'}
                </Badge>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function PoolParticipationsSection({
  participations,
  isDark,
}: {
  participations: SummaryReportPoolParticipation[];
  isDark: boolean;
}): JSX.Element {
  return (
    <div>
      <h5 className={clsx('text-sm font-medium mb-2', adminStrong(isDark))}>
        Pool-Mirror-Trade Investoren ({participations.length})
      </h5>
      <PoolParticipationsTable participations={participations} isDark={isDark} />
    </div>
  );
}
