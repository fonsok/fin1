import { useState } from 'react';
import clsx from 'clsx';
import { formatNumber } from '../../../utils/format';
import {
  adminCaption,
  adminMuted,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import { PartialSellEventsSection } from './PartialSellEventsSection';
import { TraderPartialSellsSection } from './TraderPartialSellsSection';
import { PoolParticipationsSection } from './PoolParticipationsTable';
import { PoolBelegeSection, TraderBelegeSection } from './TradeBelegeSection';
import { TradeChevronIcon, TradeLegBadge } from './TradeBadges';
import { TradeMetricsGrid } from './TradeMetricsGrid';
import type { SummaryReportTradeRow } from './types';

export function TradeExpandPanel({
  trade,
  isDark,
}: {
  trade: SummaryReportTradeRow;
  isDark: boolean;
}): JSX.Element {
  const [poolOpen, setPoolOpen] = useState(true);
  const participations = trade.poolParticipations ?? [];
  const legKind = trade.legKind ?? 'standalone';
  const rowIsPoolMirror = trade.poolMirrorTrade?.tradeId === trade.tradeId;
  const traderSnap = trade.traderTrade ?? trade.linkedTraderTrade ?? null;
  const poolSnap = trade.poolMirrorTrade ?? null;
  const traderBelege = trade.traderBelege ?? null;
  const poolBelege = trade.poolBelege ?? null;

  return (
    <div
      className={clsx(
        'border-t px-4 py-4 space-y-4',
        isDark ? 'border-slate-600 bg-sky-950/35' : 'border-gray-200 bg-blue-50/80',
      )}
    >
      <div className="space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          <h4 className={clsx('text-sm font-semibold', adminStrong(isDark))}>Trader-Trade</h4>
          <TradeLegBadge legKind={legKind} />
          {trade.pairExecutionId && (
            <span className={clsx('text-xs font-mono', adminCaption(isDark))}>
              pair: {trade.pairExecutionId.slice(0, 12)}…
            </span>
          )}
        </div>
        {traderSnap ? (
          <>
            <TradeMetricsGrid snap={traderSnap} isDark={isDark} profitLabel="P/L (Trader)" />
            {traderSnap.soldQuantity > 0 && traderSnap.buyQuantity > 0 && (
              <p className={clsx('text-xs', adminCaption(isDark))}>
                Teilverkauf: {formatNumber(traderSnap.soldQuantity)} / {formatNumber(traderSnap.buyQuantity)}{' '}
                Stk ({(traderSnap.sellVolumeProgress * 100).toFixed(1)} % verkauft).
              </p>
            )}
          </>
        ) : (
          <p className={clsx('text-sm', adminMuted(isDark))}>
            {rowIsPoolMirror
              ? 'Verknüpftes Trader-Leg (Paired Buy) — wird per Order-Paar aufgelöst.'
              : 'Keine Trader-Trade-Daten.'}
          </p>
        )}
        <TraderPartialSellsSection legs={trade.traderSellLegs} isDark={isDark} />
        <TraderBelegeSection belege={traderBelege} isDark={isDark} />
      </div>

      {(poolSnap || participations.length > 0) && (
        <div
          className={clsx(
            'rounded-lg border overflow-hidden',
            isDark ? 'border-slate-600' : 'border-blue-200',
          )}
        >
          <button
            type="button"
            className={clsx(
              'w-full flex items-center justify-between gap-3 px-4 py-3 text-left',
              isDark ? 'bg-slate-800/80 hover:bg-slate-800' : 'bg-sky-100/90 hover:bg-sky-100',
            )}
            onClick={() => setPoolOpen((v) => !v)}
            aria-expanded={poolOpen}
          >
            <span className={clsx('text-sm font-semibold', adminStrong(isDark))}>
              Pool-Mirror-Trade
              {poolSnap
                ? ` (#${String(poolSnap.tradeNumber).padStart(3, '0')} · ${poolSnap.poolInvestorCount ?? participations.length} Investoren)`
                : ''}
            </span>
            <TradeChevronIcon expanded={poolOpen} />
          </button>

          {poolOpen && (
            <div
              className={clsx(
                'px-4 py-4 space-y-4 border-t',
                isDark ? 'border-slate-600 bg-slate-900/50' : 'border-blue-200 bg-white/70',
              )}
            >
              {poolSnap ? (
                <>
                  <p className={clsx('text-xs font-mono', adminCaption(isDark))}>
                    Mirror-ID: {poolSnap.tradeId}
                  </p>
                  <TradeMetricsGrid
                    snap={poolSnap}
                    isDark={isDark}
                    profitLabel="P/L (Pool)"
                    showPoolCapital
                    poolLegMetrics
                  />
                  {poolSnap.soldQuantity > 0 && poolSnap.buyQuantity > 0 && (
                    <p className={clsx('text-xs', adminCaption(isDark))}>
                      Teilverkauf: gleicher Anteil der Trader-Stückzahl auf Pool-Stück (
                      {formatNumber(poolSnap.soldQuantity)} / {formatNumber(poolSnap.buyQuantity)} ={' '}
                      {(poolSnap.sellVolumeProgress * 100).toFixed(1)} %), jeweils abgerundet.
                    </p>
                  )}
                </>
              ) : (
                <p className={clsx('text-sm', adminMuted(isDark))}>
                  Mirror-Trade noch nicht verknüpft (keine PoolTradeParticipation / kein Paired Buy).
                </p>
              )}

              {poolSnap && <PoolBelegeSection belege={poolBelege} isDark={isDark} />}

              <PartialSellEventsSection events={trade.partialSellEvents} isDark={isDark} />

              <PoolParticipationsSection participations={participations} isDark={isDark} />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
