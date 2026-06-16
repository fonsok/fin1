import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { Badge } from '../../../components/ui';
import { getSummaryReportTradeParticipationsPage } from '../../../api/admin/reports';
import { formatCurrency, formatNumber } from '../../../utils/format';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import {
  adminBodyStrong,
  adminMonoHint,
  adminMuted,
  adminPrimary,
  adminSoft,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import { AdminUserDetailLink } from '../../../components/AdminUserDetailLink';
import type { SummaryReportPoolParticipation } from './types';

const DEFAULT_PAGE_SIZE = 50;

export function PoolParticipationsTable({
  participations,
  isDark,
  isLoading = false,
}: {
  participations: SummaryReportPoolParticipation[];
  isDark: boolean;
  isLoading?: boolean;
}): JSX.Element {
  const thClass = clsx(
    'px-3 py-2 text-xs font-medium uppercase tracking-wide',
    adminMonoHint(isDark),
  );

  if (isLoading) {
    return <p className={clsx('text-sm', adminMuted(isDark))}>Lade Investoren…</p>;
  }

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
            <th className={clsx(thClass, 'text-right')}>Provision</th>
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
                <AdminUserDetailLink
                  userId={p.investorId}
                  label={p.investorName || p.investorEmail}
                  isDark={isDark}
                />
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
              <td
                className={clsx(
                  'px-3 py-2 text-right font-medium',
                  p.profitShare >= 0
                    ? isDark
                      ? 'text-emerald-400'
                      : 'text-green-600'
                    : isDark
                      ? 'text-red-400'
                      : 'text-red-600',
                )}
              >
                {formatCurrency(p.profitShare)}
              </td>
              <td className={clsx('px-3 py-2 text-right', adminSoft(isDark))}>
                {(p.commissionAmount ?? 0) > 0
                  ? formatCurrency(p.commissionAmount ?? 0)
                  : '—'}
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
  poolTradeId,
  participationsTotal,
  participationsTruncated = false,
  participationsAggregates,
  costBasisPerShare = 0,
}: {
  participations: SummaryReportPoolParticipation[];
  isDark: boolean;
  poolTradeId?: string | null;
  participationsTotal?: number;
  participationsTruncated?: boolean;
  participationsAggregates?: {
    totalCommission: number;
    totalProfitShare: number;
  } | null;
  costBasisPerShare?: number;
}): JSX.Element {
  const [page, setPage] = useState(0);
  const pageSize = DEFAULT_PAGE_SIZE;
  const totalCount = participationsTotal ?? participations.length;

  const paginatedQuery = useQuery({
    queryKey: [
      'summaryReportTradeParticipations',
      poolTradeId,
      page,
      pageSize,
      costBasisPerShare,
    ],
    queryFn: () =>
      getSummaryReportTradeParticipationsPage({
        poolTradeId: poolTradeId as string,
        page,
        pageSize,
        costBasisPerShare,
      }),
    enabled: Boolean(participationsTruncated && poolTradeId),
    staleTime: 30_000,
  });

  const inlineTotalCommission = participations.reduce(
    (sum, p) => sum + (p.commissionAmount ?? 0),
    0,
  );
  const totalCommission = participationsTruncated
    ? (paginatedQuery.data?.aggregates.totalCommission
      ?? participationsAggregates?.totalCommission
      ?? 0)
    : inlineTotalCommission;

  const rows = participationsTruncated
    ? (paginatedQuery.data?.items ?? [])
    : participations;
  const pageTotal = participationsTruncated
    ? (paginatedQuery.data?.total ?? totalCount)
    : participations.length;
  const pageCount = Math.max(1, Math.ceil(pageTotal / pageSize));

  return (
    <div>
      <h5 className={clsx('text-sm font-medium mb-2', adminStrong(isDark))}>
        Pool-Mirror-Trade Investoren ({totalCount})
        {totalCommission > 0 && (
          <span className={clsx('font-normal', adminMuted(isDark))}>
            {' '}
            · Provision gesamt: {formatCurrency(totalCommission)}
          </span>
        )}
        {participationsTruncated && (
          <span className={clsx('block text-xs font-normal mt-1', adminMuted(isDark))}>
            Detail-Liste paginiert ({pageSize} pro Seite) — Summen aus Backend-Aggregation.
          </span>
        )}
      </h5>
      <PoolParticipationsTable
        participations={rows}
        isDark={isDark}
        isLoading={participationsTruncated && paginatedQuery.isLoading}
      />
      {participationsTruncated && pageTotal > pageSize && (
        <div className="flex items-center justify-between gap-3 mt-3">
          <p className={clsx('text-xs', adminMuted(isDark))}>
            Seite {page + 1} / {pageCount}
          </p>
          <div className="flex gap-2">
            <button
              type="button"
              className={clsx(
                'px-3 py-1 text-xs rounded border',
                isDark
                  ? 'border-slate-600 text-slate-200 disabled:opacity-40'
                  : 'border-blue-200 text-blue-900 disabled:opacity-40',
              )}
              disabled={page <= 0 || paginatedQuery.isFetching}
              onClick={() => setPage((p) => Math.max(0, p - 1))}
            >
              Zurück
            </button>
            <button
              type="button"
              className={clsx(
                'px-3 py-1 text-xs rounded border',
                isDark
                  ? 'border-slate-600 text-slate-200 disabled:opacity-40'
                  : 'border-blue-200 text-blue-900 disabled:opacity-40',
              )}
              disabled={page + 1 >= pageCount || paginatedQuery.isFetching}
              onClick={() => setPage((p) => p + 1)}
            >
              Weiter
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
