import { Link } from 'react-router-dom';
import clsx from 'clsx';
import { adminMuted } from '../../../utils/adminThemeClasses';
import type { SummaryReportTradeBelegLink } from './types';

export function BelegLinkRow({
  beleg,
  isDark,
  internal = false,
}: {
  beleg: SummaryReportTradeBelegLink;
  isDark: boolean;
  /** Interne Teilverkauf-Belege (nicht in Investor-App). */
  internal?: boolean;
}): JSX.Element {
  const href = (() => {
    const params = new URLSearchParams();
    if (beleg.documentNumber?.trim()) {
      params.set('openDocumentNumber', beleg.documentNumber.trim());
    }
    if (beleg.documentId?.trim()) {
      params.set('openDocumentId', beleg.documentId.trim());
    }
    const qs = params.toString();
    return qs ? `/documents?${qs}` : null;
  })();

  if (!href) {
    return (
      <span className={clsx('text-sm', adminMuted(isDark))}>
        {beleg.label} ({beleg.documentNumber || '—'})
      </span>
    );
  }

  return (
    <span className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5">
      <Link
        to={href}
        className={clsx(
          'text-sm font-medium underline underline-offset-2',
          internal
            ? isDark
              ? 'text-amber-300/90 hover:text-amber-200'
              : 'text-amber-800 hover:text-amber-900'
            : isDark
              ? 'text-sky-300 hover:text-sky-200'
              : 'text-fin1-primary hover:text-fin1-primary/80',
        )}
      >
        {beleg.label}
        {beleg.documentNumber ? ` · ${beleg.documentNumber}` : ''}
      </Link>
      {internal && (
        <span
          className={clsx(
            'text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded border',
            isDark ? 'border-amber-600/50 text-amber-400/90' : 'border-amber-300 text-amber-800',
          )}
        >
          intern
        </span>
      )}
    </span>
  );
}
