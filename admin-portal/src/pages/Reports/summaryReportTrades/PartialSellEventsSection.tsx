import clsx from 'clsx';
import { formatCurrency, formatNumber } from '../../../utils/format';
import {
  adminCaption,
  adminMuted,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import { BelegLinkRow } from './BelegLinkRow';
import type { SummaryReportPartialSellEvent } from './types';

function InvestorRealizationsTable({
  event,
  isDark,
}: {
  event: SummaryReportPartialSellEvent;
  isDark: boolean;
}): JSX.Element | null {
  const rows = event.investorRealizations ?? [];
  if (!rows.length) return null;

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-xs border-collapse">
        <thead>
          <tr className={clsx(isDark ? 'text-slate-400' : 'text-gray-500')}>
            <th className="text-left py-1 pr-3 font-medium">Investor</th>
            <th className="text-right py-1 px-2 font-medium">Stück</th>
            <th className="text-right py-1 px-2 font-medium">Verkauf €</th>
            <th className="text-right py-1 px-2 font-medium">Brutto</th>
            <th className="text-right py-1 px-2 font-medium">Prov.</th>
            <th className="text-right py-1 pl-2 font-medium">Netto</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.investmentId || r.investorId} className={clsx(isDark ? 'text-slate-200' : 'text-gray-800')}>
              <td className="py-1 pr-3">
                <span className="font-medium">{r.investorName || '—'}</span>
                {r.investmentNumber && (
                  <span className={clsx('block font-mono', adminCaption(isDark))}>{r.investmentNumber}</span>
                )}
              </td>
              <td className="text-right py-1 px-2 font-mono">{formatNumber(r.sellQuantity)}</td>
              <td className="text-right py-1 px-2 font-mono">{formatCurrency(r.sellAmount)}</td>
              <td className="text-right py-1 px-2 font-mono">{formatCurrency(r.grossProfit)}</td>
              <td className="text-right py-1 px-2 font-mono">{formatCurrency(r.commission)}</td>
              <td className="text-right py-1 pl-2 font-mono">{formatCurrency(r.netProfit)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function PartialSellEventsSection({
  events,
  isDark,
}: {
  events: SummaryReportPartialSellEvent[] | undefined;
  isDark: boolean;
}): JSX.Element | null {
  if (!events?.length) return null;

  return (
    <div className="space-y-3">
      <div>
        <p className={clsx('text-sm font-semibold', adminStrong(isDark))}>
          Teilverkauf-Events ({events.length})
        </p>
        <p className={clsx('text-xs mt-0.5', adminCaption(isDark))}>
          Pro Verkaufsbewegung: Trader-Delta, abgeleitete Pool-Stück (abrunden) und Investor-Realisierung
          (gleiche Logik wie Settlement).
        </p>
      </div>

      <div className="space-y-3">
        {events.map((event) => (
          <div
            key={event.eventIndex}
            className={clsx(
              'rounded-md border px-3 py-3 space-y-2',
              isDark ? 'border-slate-600 bg-slate-800/40' : 'border-blue-100 bg-white',
            )}
          >
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <span className={clsx('text-sm font-semibold', adminStrong(isDark))}>
                Event #{event.eventIndex}
                {event.isFinalExit ? ' · Vollständiger Exit' : ''}
              </span>
              <span className={clsx('text-xs font-mono', adminCaption(isDark))}>
                Trader: {formatNumber(event.traderSellQuantity)} Stk
                {' '}(Σ {formatNumber(event.traderSellQuantityCumulative)} /{' '}
                {(event.traderSellVolumeProgress * 100).toFixed(1)} %)
                · {formatCurrency(event.traderSellAmount)}
                {event.traderSellPrice > 0 ? ` @ ${formatNumber(event.traderSellPrice)} €` : ''}
              </span>
              {event.poolSellQuantity > 0 && (
                <span className={clsx('text-xs font-mono', adminCaption(isDark))}>
                  Pool: +{formatNumber(event.poolSellQuantity)} Stk
                  {' '}(Σ {formatNumber(event.poolSellQuantityCumulative)})
                  {event.poolSellAmount > 0 ? ` · ${formatCurrency(event.poolSellAmount)}` : ''}
                  {(event.poolSellFeesTotal ?? 0) > 0
                    ? ` · Geb. ${formatCurrency(event.poolSellFeesTotal ?? 0)}`
                    : ''}
                  {(event.poolNetSellAmount ?? 0) > 0
                    ? ` · netto ${formatCurrency(event.poolNetSellAmount ?? 0)}`
                    : ''}
                </span>
              )}
            </div>

            <InvestorRealizationsTable event={event} isDark={isDark} />

            <div className="flex flex-col gap-1 pt-1">
              <p className={clsx('text-xs font-medium', adminCaption(isDark))}>Belege dieses Events</p>
              {event.traderSellBeleg && (
                <BelegLinkRow beleg={event.traderSellBeleg} isDark={isDark} />
              )}
              {event.poolMirrorSellBeleg && (
                <BelegLinkRow beleg={event.poolMirrorSellBeleg} isDark={isDark} internal />
              )}
              {(event.investorPartialSellBelege ?? []).map((b) => (
                <BelegLinkRow key={b.documentId} beleg={b} isDark={isDark} internal />
              ))}
              {!event.traderSellBeleg
                && !event.poolMirrorSellBeleg
                && !(event.investorPartialSellBelege ?? []).length && (
                <span className={clsx('text-xs', adminMuted(isDark))}>Keine verknüpften Belege.</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
