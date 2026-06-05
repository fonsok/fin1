import { Fragment, useState, useCallback, type ReactNode } from 'react';
import clsx from 'clsx';
import { Card, PaginationBar } from '../../../components/ui';
import { SortableTh, type SortOrder } from '../../../components/table/SortableTh';
import { formatCurrency, formatDateTime } from '../../../utils/format';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import {
  adminBodyStrong,
  adminBorderChromeSoft,
  adminCaption,
  adminMuted,
  adminPrimary,
} from '../../../utils/adminThemeClasses';
import { TradeChevronIcon, TradeLegBadge, TradeStatusBadge } from './TradeBadges';
import { TradeExpandPanel } from './TradeExpandPanel';
import type { SummaryReportTradeRow } from './types';

export function SummaryReportTradesTable({
  items,
  total,
  page,
  pageSize,
  sortBy,
  sortOrder,
  isLoading,
  isDark,
  toolbar,
  emptyMessage = 'Keine Trades gefunden',
  onPageChange,
  onSort,
}: {
  items: SummaryReportTradeRow[];
  total: number;
  page: number;
  pageSize: number;
  sortBy: string;
  sortOrder: SortOrder;
  isLoading: boolean;
  isDark: boolean;
  toolbar?: ReactNode;
  emptyMessage?: string;
  onPageChange: (page: number) => void;
  onSort: (field: string) => void;
}): JSX.Element {
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());

  const toggleExpanded = useCallback((tradeId: string) => {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(tradeId)) next.delete(tradeId);
      else next.add(tradeId);
      return next;
    });
  }, []);

  const thClass = clsx('px-4 py-3 text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark));

  if (isLoading && items.length === 0 && !toolbar) {
    return (
      <Card>
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>Trades werden geladen...</div>
      </Card>
    );
  }

  return (
    <Card>
      {toolbar && (
        <div className={clsx('p-4 border-b', adminBorderChromeSoft(isDark))}>{toolbar}</div>
      )}
      {isLoading && items.length === 0 ? (
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>Trades werden geladen...</div>
      ) : total === 0 ? (
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>{emptyMessage}</div>
      ) : (
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className={tableTheadSurfaceClasses(isDark)}>
            <tr>
              <th className={clsx(thClass, 'w-10')} aria-label="Details" />
              <SortableTh
                label="Nr."
                field="tradeNumber"
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onSort}
                className={clsx(thClass, 'text-left')}
              />
              <th className={clsx(thClass, 'text-left')}>Symbol</th>
              <th className={clsx(thClass, 'text-left')}>Leg</th>
              <th className={clsx(thClass, 'text-right')}>Kauf</th>
              <th className={clsx(thClass, 'text-right')}>Verkauf</th>
              <th className={clsx(thClass, 'text-right')}>Gewinn</th>
              <th className={clsx(thClass, 'text-center')}>Investoren</th>
              <th className={clsx(thClass, 'text-left')}>Status</th>
              <SortableTh
                label="Datum"
                field="createdAt"
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onSort}
                className={clsx(thClass, 'text-left')}
              />
            </tr>
          </thead>
          <tbody className={tableBodyDivideClasses(isDark)}>
            {items.map((trade, index) => (
              <SummaryReportTradeTableRow
                key={trade.tradeId}
                trade={trade}
                index={index}
                isDark={isDark}
                expanded={expandedIds.has(trade.tradeId)}
                onToggleExpand={() => toggleExpanded(trade.tradeId)}
              />
            ))}
          </tbody>
        </table>
      </div>
      )}
      {total > 0 && (
        <PaginationBar
          page={page}
          pageSize={pageSize}
          total={total}
          itemLabel="Trades"
          isDark={isDark}
          onPageChange={onPageChange}
        />
      )}
    </Card>
  );
}

function SummaryReportTradeTableRow({
  trade,
  index,
  isDark,
  expanded,
  onToggleExpand,
}: {
  trade: SummaryReportTradeRow;
  index: number;
  isDark: boolean;
  expanded: boolean;
  onToggleExpand: () => void;
}): JSX.Element {
  const participations = trade.poolParticipations ?? [];
  const legKind = trade.legKind ?? 'standalone';
  const investorCount =
    participations.length > 0 ? participations.length : trade.investorIds.length;
  const canExpand =
    trade.hasPoolDetails === true
    || participations.length > 0
    || Boolean(trade.traderTrade || trade.poolMirrorTrade);

  return (
    <Fragment>
      <tr className={listRowStripeClasses(isDark, index)}>
        <td className="px-2 py-3 text-center">
          {canExpand ? (
            <button
              type="button"
              onClick={onToggleExpand}
              className={clsx(
                'p-1 rounded hover:bg-black/5 dark:hover:bg-white/10',
                adminMuted(isDark),
              )}
              aria-expanded={expanded}
              aria-label={`Trader- und Pool-Details Trade ${trade.tradeNumber}`}
            >
              <TradeChevronIcon expanded={expanded} />
            </button>
          ) : (
            <span className={clsx('text-xs', adminCaption(isDark))}>—</span>
          )}
        </td>
        <td className={clsx('px-4 py-3 text-sm font-mono', adminBodyStrong(isDark))}>
          {String(trade.tradeNumber).padStart(3, '0')}
        </td>
        <td className={clsx('px-4 py-3 text-sm font-medium', adminPrimary(isDark))}>
          {trade.symbol}
        </td>
        <td className="px-4 py-3">
          <TradeLegBadge legKind={legKind} />
        </td>
        <td className={clsx('px-4 py-3 text-sm text-right', adminBodyStrong(isDark))}>
          {formatCurrency(trade.buyAmount)}
        </td>
        <td className={clsx('px-4 py-3 text-sm text-right', adminBodyStrong(isDark))}>
          {formatCurrency(trade.sellAmount)}
        </td>
        <td
          className={clsx(
            'px-4 py-3 text-sm text-right font-medium',
            trade.profit >= 0
              ? isDark
                ? 'text-green-400'
                : 'text-green-600'
              : isDark
                ? 'text-red-400'
                : 'text-red-600',
          )}
        >
          {formatCurrency(trade.profit)}
        </td>
        <td className={clsx('px-4 py-3 text-sm text-center', adminBodyStrong(isDark))}>
          {investorCount}
        </td>
        <td className="px-4 py-3">
          <TradeStatusBadge status={trade.status} />
        </td>
        <td className={clsx('px-4 py-3 text-sm', adminMuted(isDark))}>
          {formatDateTime(trade.createdAt)}
        </td>
      </tr>
      {expanded && canExpand && (
        <tr>
          <td colSpan={10} className="p-0">
            <TradeExpandPanel trade={trade} isDark={isDark} />
          </td>
        </tr>
      )}
    </Fragment>
  );
}
