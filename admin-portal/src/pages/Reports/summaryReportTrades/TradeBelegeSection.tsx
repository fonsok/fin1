import clsx from 'clsx';
import { adminCaption, adminMonoHint, adminMuted } from '../../../utils/adminThemeClasses';
import { BelegLinkRow } from './BelegLinkRow';
import type {
  SummaryReportPoolBelege,
  SummaryReportTradeBelegLink,
  SummaryReportTraderBelege,
} from './types';

function BelegList({
  title,
  items,
  isDark,
  emptyHint,
}: {
  title: string;
  items: SummaryReportTradeBelegLink[];
  isDark: boolean;
  emptyHint?: string;
}): JSX.Element | null {
  if (!items.length) return emptyHint ? (
    <span className={clsx('text-sm', adminMuted(isDark))}>{emptyHint}</span>
  ) : null;
  return (
    <div className="space-y-1">
      <p className={clsx('text-xs font-medium', adminCaption(isDark))}>{title}</p>
      {items.map((b) => (
        <BelegLinkRow key={b.documentId} beleg={b} isDark={isDark} internal={b.visibility === 'internal'} />
      ))}
    </div>
  );
}

export function TraderBelegeSection({
  belege,
  isDark,
}: {
  belege: SummaryReportTraderBelege | null | undefined;
  isDark: boolean;
}): JSX.Element | null {
  if (!belege) return null;
  const hasAny =
    belege.buy
    || belege.sells.length > 0
    || belege.creditNote;
  if (!hasAny) {
    return (
      <p className={clsx('text-sm', adminMuted(isDark))}>
        Keine Trader-Belege (Kauf/Verkauf/Rechnung/Gutschrift) zu diesem Trade gefunden.
      </p>
    );
  }
  return (
    <div className="space-y-3">
      <p className={clsx('text-xs font-medium uppercase tracking-wide', adminMonoHint(isDark))}>
        Belege (Trader)
      </p>
      {belege.buy && <BelegLinkRow beleg={belege.buy} isDark={isDark} />}
      <BelegList title="Verkäufe" items={belege.sells} isDark={isDark} />
      {belege.creditNote && <BelegLinkRow beleg={belege.creditNote} isDark={isDark} />}
    </div>
  );
}

export function PoolBelegeSection({
  belege,
  isDark,
}: {
  belege: SummaryReportPoolBelege | null | undefined;
  isDark: boolean;
}): JSX.Element | null {
  if (!belege) return null;
  const { traderExecution, investorFullSettlement, investorPartialSells } = belege;
  const hasAny =
    traderExecution.buy
    || traderExecution.sells.length > 0
    || investorFullSettlement.length > 0
    || investorPartialSells.length > 0;
  if (!hasAny) {
    return (
      <p className={clsx('text-sm', adminMuted(isDark))}>
        Keine Pool-/Investor-Belege zu diesem Mirror-Trade gefunden.
      </p>
    );
  }
  return (
    <div className="space-y-4">
      <p className={clsx('text-xs font-medium uppercase tracking-wide', adminMonoHint(isDark))}>
        Belege (Pool-Mirror)
      </p>

      {(traderExecution.buy || traderExecution.sells.length > 0) && (
        <div className="space-y-2">
          <p className={clsx('text-xs', adminCaption(isDark))}>
            Eigenbelege Pool-Mirror (intern, nicht in Investor-/Trader-App)
          </p>
          {traderExecution.buy && (
            <BelegLinkRow beleg={traderExecution.buy} isDark={isDark} internal />
          )}
          <BelegList title="Verkäufe (Pool-Mirror)" items={traderExecution.sells} isDark={isDark} />
        </div>
      )}

      {investorFullSettlement.length > 0 && (
        <div className="space-y-2">
          <p className={clsx('text-xs', adminCaption(isDark))}>
            Collection Bills — Abschluss / 100 % Verkauf (Investor, sichtbar)
          </p>
          {investorFullSettlement.map((b) => (
            <BelegLinkRow key={b.documentId} beleg={b} isDark={isDark} />
          ))}
        </div>
      )}

      {investorPartialSells.length > 0 && (
        <div className="space-y-2">
          <p className={clsx('text-xs', adminCaption(isDark))}>
            Teilverkauf — interne Eigenbelege (Collection Bill, nicht in Investor-App)
          </p>
          {investorPartialSells.map((b) => (
            <BelegLinkRow key={b.documentId} beleg={b} isDark={isDark} internal />
          ))}
        </div>
      )}
    </div>
  );
}
