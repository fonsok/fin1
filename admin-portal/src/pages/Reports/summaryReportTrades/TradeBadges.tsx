import clsx from 'clsx';
import { Badge } from '../../../components/ui';
import type { SummaryReportTradeLegKind } from './types';

export function TradeStatusBadge({ status }: { status: string }): JSX.Element {
  const variant =
    status === 'completed' ? 'success' : status === 'active' ? 'info' : 'neutral';
  return <Badge variant={variant}>{status}</Badge>;
}

export function TradeLegBadge({ legKind }: { legKind: SummaryReportTradeLegKind }): JSX.Element {
  if (legKind === 'trader') {
    return <Badge variant="neutral">Trader-Leg</Badge>;
  }
  if (legKind === 'mirror_pool') {
    return <Badge variant="info">Pool-Mirror</Badge>;
  }
  return <Badge variant="neutral">Einzel</Badge>;
}

export function TradeChevronIcon({ expanded }: { expanded: boolean }): JSX.Element {
  return (
    <svg
      className={clsx('w-5 h-5 transition-transform shrink-0', expanded && 'rotate-180')}
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
      aria-hidden
    >
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
    </svg>
  );
}
