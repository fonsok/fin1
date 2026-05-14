import { useState } from 'react';
import clsx from 'clsx';
import { Badge, getStatusVariant } from '../../../components/ui';
import { formatDateTime, formatCurrency, getStatusDisplay } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import type { TradeItem, TradeInvestor } from '../../../api/admin';

import { adminBodyStrong, adminMonoHint, adminMuted, adminPrimary, adminSoft, adminStrong } from '../../../utils/adminThemeClasses';
export function UserTradeCard({ trade }: { trade: TradeItem }) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [expanded, setExpanded] = useState(false);
  const hasInvestors = trade.investors && trade.investors.length > 0;

  return (
    <div
      className={clsx(
        'border rounded-lg overflow-hidden',
        isDark ? 'border-slate-600' : 'border-gray-200',
      )}
    >
      <div
        className={clsx(
          'p-4 flex items-center justify-between',
          isDark ? 'bg-slate-800/95' : 'bg-white',
          hasInvestors && (isDark ? 'cursor-pointer hover:bg-slate-800' : 'cursor-pointer hover:bg-gray-50'),
        )}
        onClick={() => hasInvestors && setExpanded(!expanded)}
        onKeyDown={(e) => {
          if (!hasInvestors) return;
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            setExpanded((v) => !v);
          }
        }}
        role={hasInvestors ? 'button' : undefined}
        tabIndex={hasInvestors ? 0 : undefined}
        aria-expanded={hasInvestors ? expanded : undefined}
        aria-label={hasInvestors ? `Trade ${trade.tradeNumber}, Investoren ${expanded ? 'einklappen' : 'anzeigen'}` : undefined}
      >
        <div className="flex items-center gap-4 min-w-0">
          <span className="font-mono font-bold text-fin1-primary shrink-0">#{trade.tradeNumber}</span>
          <div className="min-w-0">
            <p className={clsx('font-medium font-mono text-sm', adminPrimary(isDark))}>
              {trade.symbol}
            </p>
            <p className={clsx('text-sm truncate', adminMuted(isDark))}>
              {trade.description}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-4 sm:gap-6 shrink-0">
          <div className="text-right">
            <p
              className={clsx(
                'font-bold',
                (trade.netProfit || trade.grossProfit || 0) >= 0
                  ? isDark
                    ? 'text-emerald-400'
                    : 'text-green-600'
                  : isDark
                    ? 'text-red-400'
                    : 'text-red-600',
              )}
            >
              {formatCurrency(trade.netProfit || trade.grossProfit || 0)}
            </p>
            <p className={clsx('text-xs', adminMuted(isDark))}>Netto-Gewinn</p>
          </div>
          <Badge variant={getStatusVariant(trade.status)}>
            {getStatusDisplay(trade.status)}
          </Badge>
          {hasInvestors && (
            <div className={clsx('flex items-center gap-1', adminSoft(isDark))}>
              <span className="text-sm whitespace-nowrap">
                {trade.investors?.length} Investor{trade.investors?.length !== 1 ? 'en' : ''}
              </span>
              <svg
                className={clsx('w-5 h-5 transition-transform shrink-0', expanded && 'rotate-180')}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          )}
        </div>
      </div>

      <div
        className={clsx(
          'px-4 py-2 text-xs flex flex-wrap gap-x-4 gap-y-1',
          isDark ? 'bg-slate-900/80 text-slate-300 border-t border-slate-600' : 'bg-gray-50 text-gray-600',
        )}
      >
        <span>Erstellt: {formatDateTime(trade.createdAt)}</span>
        {trade.completedAt && <span>Abgeschlossen: {formatDateTime(trade.completedAt)}</span>}
        {trade.investors && trade.investors.length > 0 && (
          <span>Provision: {formatCurrency(trade.investors.reduce((s, i) => s + (i.commissionAmount || 0), 0))}</span>
        )}
      </div>

      {expanded && hasInvestors && (
        <div
          className={clsx(
            'border-t p-4',
            isDark ? 'border-slate-600 bg-slate-900/60' : 'border-gray-200 bg-blue-50',
          )}
        >
          <h5 className={clsx('font-medium text-sm mb-3', adminStrong(isDark))}>
            Beteiligte Investoren
          </h5>
          <div className="overflow-x-auto rounded-lg border border-transparent">
            <table className="w-full text-sm">
              <thead className={clsx(isDark ? 'bg-slate-800/90' : 'bg-blue-100')}>
                <tr>
                  <th
                    className={clsx(
                      'px-3 py-2 text-left text-xs font-medium uppercase tracking-wide',
                      adminMonoHint(isDark),
                    )}
                  >
                    Investor
                  </th>
                  <th
                    className={clsx(
                      'px-3 py-2 text-right text-xs font-medium uppercase tracking-wide',
                      adminMonoHint(isDark),
                    )}
                  >
                    Anteil
                  </th>
                  <th
                    className={clsx(
                      'px-3 py-2 text-right text-xs font-medium uppercase tracking-wide',
                      adminMonoHint(isDark),
                    )}
                  >
                    Investiert
                  </th>
                  <th
                    className={clsx(
                      'px-3 py-2 text-right text-xs font-medium uppercase tracking-wide',
                      adminMonoHint(isDark),
                    )}
                  >
                    Gewinn-Anteil
                  </th>
                  <th
                    className={clsx(
                      'px-3 py-2 text-right text-xs font-medium uppercase tracking-wide',
                      adminMonoHint(isDark),
                    )}
                  >
                    Provision
                  </th>
                  <th
                    className={clsx(
                      'px-3 py-2 text-center text-xs font-medium uppercase tracking-wide',
                      adminMonoHint(isDark),
                    )}
                  >
                    Status
                  </th>
                </tr>
              </thead>
              <tbody className={clsx(isDark ? 'divide-y divide-slate-700' : 'divide-y divide-blue-100')}>
                {trade.investors?.map((inv: TradeInvestor, idx: number) => (
                  <tr key={idx} className={listRowStripeClasses(isDark, idx, { hover: false })}>
                    <td className="px-3 py-2">
                      <p className={clsx('font-medium', adminPrimary(isDark))}>
                        {inv.investorName}
                      </p>
                      <p className={clsx('text-xs', adminMuted(isDark))}>
                        {inv.investorEmail}
                      </p>
                    </td>
                    <td className={clsx('px-3 py-2 text-right font-mono', adminBodyStrong(isDark))}>
                      {((inv.ownershipPercentage || 0) <= 1
                        ? (inv.ownershipPercentage || 0) * 100
                        : (inv.ownershipPercentage || 0)
                      ).toFixed(1)}%
                    </td>
                    <td className={clsx('px-3 py-2 text-right', adminPrimary(isDark))}>
                      {formatCurrency(inv.investedAmount || 0)}
                    </td>
                    <td
                      className={clsx(
                        'px-3 py-2 text-right font-medium',
                        (inv.profitShare || 0) >= 0
                          ? isDark
                            ? 'text-emerald-400'
                            : 'text-green-600'
                          : isDark
                            ? 'text-red-400'
                            : 'text-red-600',
                      )}
                    >
                      {formatCurrency(inv.profitShare || 0)}
                    </td>
                    <td className={clsx('px-3 py-2 text-right', adminSoft(isDark))}>
                      {formatCurrency(inv.commissionAmount || 0)}
                    </td>
                    <td className="px-3 py-2 text-center">
                      <Badge variant={inv.isSettled ? 'success' : 'warning'}>
                        {inv.isSettled ? 'Abgerechnet' : 'Offen'}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
