import clsx from 'clsx';
import { formatCurrency, formatCurrencyPerShare, formatNumber } from '../../../utils/format';
import { formatTradeNumberHash } from '../../../utils/tradeNumberFormat';
import {
  adminBodyStrong,
  adminCaption,
  adminMuted,
} from '../../../utils/adminThemeClasses';
import { TradeStatusBadge } from './TradeBadges';
import type { SummaryReportTradeEconomics } from './types';

export function TradeMetricsGrid({
  snap,
  isDark,
  profitLabel = 'Gewinn',
  showPoolCapital = false,
  poolLegMetrics = false,
}: {
  snap: SummaryReportTradeEconomics;
  isDark: boolean;
  profitLabel?: string;
  showPoolCapital?: boolean;
  /** Pool-Mirror: Stück/Kauf aus abgeleiteter Pool-Logik, nicht Roh-Trade. */
  poolLegMetrics?: boolean;
}): JSX.Element {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 text-sm">
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Trade-Nr.</p>
        <p className={clsx('font-mono', adminBodyStrong(isDark))}>
          {formatTradeNumberHash(snap.tradeNumber, snap.tradeNumberYear, snap.createdAt)}
        </p>
      </div>
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Symbol / WKN</p>
        <p className={adminBodyStrong(isDark)}>{snap.symbol}</p>
        {snap.wknOrIsin && snap.wknOrIsin !== snap.symbol && (
          <p className={clsx('text-xs font-mono', adminMuted(isDark))}>WKN/ISIN: {snap.wknOrIsin}</p>
        )}
      </div>
      {snap.isin && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>ISIN</p>
          <p className={clsx('font-mono text-xs', adminBodyStrong(isDark))}>{snap.isin}</p>
        </div>
      )}
      {snap.underlyingAsset && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Basiswert</p>
          <p className={adminBodyStrong(isDark)}>{snap.underlyingAsset}</p>
        </div>
      )}
      {snap.optionDirection && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Richtung</p>
          <p className={adminBodyStrong(isDark)}>{snap.optionDirection}</p>
        </div>
      )}
      {snap.strikePrice != null && snap.strikePrice > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Strike</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.strikePrice)}</p>
        </div>
      )}
      {snap.issuer && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Emittent</p>
          <p className={adminBodyStrong(isDark)}>{snap.issuer}</p>
        </div>
      )}
      {showPoolCapital && (snap.poolReservedCapitalTotal ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Reserved (∑ Investments)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.poolReservedCapitalTotal ?? 0)}</p>
        </div>
      )}
      {showPoolCapital && (snap.poolCapitalAllocated ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Pool-Einlage (Σ Stück × Einstand)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.poolCapitalAllocated ?? 0)}</p>
        </div>
      )}
      {showPoolCapital && (snap.poolResidualTotal ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Residual (Reserved − Active @ Einstand)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.poolResidualTotal ?? 0)}</p>
        </div>
      )}
      {showPoolCapital && snap.impliedBuyQuantityFromPool != null && snap.impliedBuyQuantityFromPool > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Stück (Σ active @ Einstand)</p>
          <p className={adminBodyStrong(isDark)}>{formatNumber(snap.impliedBuyQuantityFromPool)}</p>
        </div>
      )}
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>
          {poolLegMetrics ? 'Kauf (Stück, Pool)' : 'Kauf (Stück, Trade)'}
        </p>
        <p className={adminBodyStrong(isDark)}>{formatNumber(snap.buyQuantity)}</p>
      </div>
      {(snap.buyFeesTotal ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Σ Gebühren (Kauf)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.buyFeesTotal ?? 0)}</p>
        </div>
      )}
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Bid (nominell / Stück)</p>
        <p className={adminBodyStrong(isDark)}>
          {(snap.bidPricePerShare ?? 0) > 0
            ? formatCurrency(snap.bidPricePerShare ?? 0)
            : '—'}
        </p>
      </div>
      {(snap.costBasisPerShare ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Einstand / Bezug (pro Stück)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrencyPerShare(snap.costBasisPerShare ?? 0)}</p>
        </div>
      )}
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Verkauft (Stück)</p>
        <p className={adminBodyStrong(isDark)}>{formatNumber(snap.soldQuantity)}</p>
      </div>
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Ask (nominell / Stück)</p>
        <p className={adminBodyStrong(isDark)}>
          {(snap.askPricePerShare ?? 0) > 0
            ? formatCurrency(snap.askPricePerShare ?? 0)
            : '—'}
        </p>
      </div>
      {(snap.sellFeesTotal ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Σ Gebühren (Verkauf)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.sellFeesTotal ?? 0)}</p>
        </div>
      )}
      {(snap.netSellPricePerShare ?? 0) > 0 && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Verkauf netto (pro Stück)</p>
          <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.netSellPricePerShare ?? 0)}</p>
        </div>
      )}
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Verkaufs-Fortschritt</p>
        <p className={adminBodyStrong(isDark)}>{(snap.sellVolumeProgress * 100).toFixed(1)}%</p>
      </div>
      {!poolLegMetrics && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Kaufvolumen (Einstand)</p>
          <p className={adminBodyStrong(isDark)}>
            {(snap.totalBuyCost ?? 0) > 0 ? formatCurrency(snap.totalBuyCost ?? 0) : '—'}
          </p>
        </div>
      )}
      {!poolLegMetrics && (
        <div>
          <p className={clsx('text-xs', adminCaption(isDark))}>Verkaufsvolumen (netto)</p>
          <p className={adminBodyStrong(isDark)}>
            {(snap.netSellAmount ?? 0) > 0 ? formatCurrency(snap.netSellAmount ?? 0) : '—'}
          </p>
        </div>
      )}
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>{profitLabel}</p>
        <p className={adminBodyStrong(isDark)}>{formatCurrency(snap.profit)}</p>
      </div>
      <div>
        <p className={clsx('text-xs', adminCaption(isDark))}>Status</p>
        <TradeStatusBadge status={snap.status} />
      </div>
    </div>
  );
}
