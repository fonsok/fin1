import { useState } from 'react';
import clsx from 'clsx';
import {
  adminCaption,
  adminPrimary,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import { BelegLinkRow } from './BelegLinkRow';
import { TradeChevronIcon } from './TradeBadges';
import type { SummaryReportTraderSellLeg } from './types';

function DetailRow({
  label,
  value,
  isDark,
  emphasize = false,
  positive = false,
}: {
  label: string;
  value: string;
  isDark: boolean;
  emphasize?: boolean;
  positive?: boolean;
}): JSX.Element {
  return (
    <div className="flex items-baseline justify-between gap-2 text-xs">
      <span className={clsx(emphasize ? 'font-semibold' : 'font-normal', adminCaption(isDark))}>
        {label}
      </span>
      <span
        className={clsx(
          'font-mono text-right shrink-0',
          emphasize && 'font-semibold',
          positive
            ? isDark
              ? 'text-green-400'
              : 'text-green-700'
            : adminPrimary(isDark),
        )}
      >
        {value}
      </span>
    </div>
  );
}

const FEE_LABELS = new Set(['Ordergebühr', 'Handelsplatzgebühr', 'Fremdkostenpauschale']);
const ORDER_LABELS = new Set(['Ordervolumen', 'davon ausgef.', 'Kurs (Bid)', 'Kurs (Ask)', 'Kurswert']);

function splitVerkaufRows(rows: SummaryReportTraderSellLeg['verkaufRows']) {
  const sumRow = rows.find((r) => r.label.startsWith('Σ VERKAUF')) ?? null;
  const orderRows = rows.filter((r) => ORDER_LABELS.has(r.label));
  const feeRows = rows.filter((r) => FEE_LABELS.has(r.label));
  const metaRows = rows.filter(
    (r) => !r.label.startsWith('Σ VERKAUF') && !ORDER_LABELS.has(r.label) && !FEE_LABELS.has(r.label),
  );
  return { sumRow, orderRows, feeRows, metaRows };
}

function TraderSellLegCard({
  leg,
  isDark,
}: {
  leg: SummaryReportTraderSellLeg;
  isDark: boolean;
}): JSX.Element {
  const { sumRow, orderRows, feeRows, metaRows } = splitVerkaufRows(leg.verkaufRows);

  return (
    <div
      className={clsx(
        'rounded-lg border px-3 py-2.5 space-y-2 min-w-0 h-full',
        isDark ? 'border-slate-600 bg-slate-800/50' : 'border-blue-100 bg-white',
      )}
    >
      <div className="space-y-1">
        <p className={clsx('text-xs font-semibold', adminStrong(isDark))}>{leg.title}</p>
        {leg.instrumentLine && (
          <p className={clsx('text-xs leading-snug', adminCaption(isDark))}>{leg.instrumentLine}</p>
        )}
        {leg.documentNumber && (
          <BelegLinkRow
            beleg={{
              documentId: leg.documentId,
              documentNumber: leg.documentNumber,
              documentType: 'traderCollectionBill',
              executionType: 'sell',
              label: leg.documentNumber,
            }}
            isDark={isDark}
          />
        )}
      </div>

      {orderRows.length > 0 && (
        <div className="space-y-2">
          {orderRows.map((row) => (
            <DetailRow key={row.label} label={`${row.label}:`} value={row.value} isDark={isDark} />
          ))}
        </div>
      )}

      {feeRows.length > 0 && (
        <>
          <div className={clsx('border-t', isDark ? 'border-slate-600' : 'border-gray-200')} />
          <div className="space-y-2">
            {feeRows.map((row) => (
              <DetailRow key={row.label} label={`${row.label}:`} value={row.value} isDark={isDark} />
            ))}
          </div>
        </>
      )}

      {sumRow && (
        <>
          <div className={clsx('border-t', isDark ? 'border-slate-600' : 'border-gray-200')} />
          <DetailRow
            label={`${sumRow.label}:`}
            value={sumRow.value}
            isDark={isDark}
            emphasize
            positive
          />
        </>
      )}

      {metaRows.length > 0 && (
        <>
          <div className={clsx('border-t', isDark ? 'border-slate-600' : 'border-gray-200')} />
          <div className="space-y-2">
            {metaRows.map((row) => (
              <DetailRow key={row.label} label={`${row.label}:`} value={row.value} isDark={isDark} />
            ))}
          </div>
        </>
      )}

      {leg.partialSellRows.length > 0 && (
        <div className="space-y-2 pt-1">
          <p className={clsx('text-xs font-medium uppercase tracking-wide', adminCaption(isDark))}>
            Teilverkauf
          </p>
          {leg.partialSellRows.map((row) => (
            <DetailRow key={row.label} label={`${row.label}:`} value={row.value} isDark={isDark} />
          ))}
        </div>
      )}
    </div>
  );
}

export function TraderPartialSellsSection({
  legs,
  isDark,
}: {
  legs: SummaryReportTraderSellLeg[] | undefined;
  isDark: boolean;
}): JSX.Element | null {
  const [open, setOpen] = useState(false);
  if (!legs?.length) return null;

  return (
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
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
      >
        <span className="min-w-0">
          <span className={clsx('text-sm font-semibold block', adminStrong(isDark))}>
            Trader-(Teil-)Verkäufe ({legs.length})
          </span>
          <span className={clsx('text-xs mt-0.5 block', adminCaption(isDark))}>
            Einzelne (Teil-)Verkaufsabrechnungen wie in der Trader Collection Bill
          </span>
        </span>
        <TradeChevronIcon expanded={open} />
      </button>

      {open && (
        <div
          className={clsx(
            'px-4 py-4 border-t',
            isDark ? 'border-slate-600 bg-slate-900/40' : 'border-blue-200 bg-white/70',
          )}
        >
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
            {legs.map((leg) => (
              <TraderSellLegCard key={leg.documentId} leg={leg} isDark={isDark} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
