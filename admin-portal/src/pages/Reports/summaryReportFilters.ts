import type { AdminTableFilterSelect } from '../../components/filters/AdminTableFilterBar';

export const INVESTMENT_STATUS_FILTER_OPTIONS = [
  { value: '', label: 'Alle' },
  { value: 'reserved', label: 'Reserviert' },
  { value: 'active', label: 'Aktiv' },
  { value: 'executing', label: 'Ausführend' },
  { value: 'paused', label: 'Pausiert' },
  { value: 'closing', label: 'Schließend' },
  { value: 'completed', label: 'Abgeschlossen' },
  { value: 'cancelled', label: 'Storniert' },
];

export const INVESTMENT_RETURN_FILTER_OPTIONS = [
  { value: '', label: 'Alle' },
  { value: 'positive', label: 'Buchwert > Einsatz' },
  { value: 'negative', label: 'Buchwert < Einsatz' },
  { value: 'zero', label: 'Buchwert = Einsatz' },
];

export const TRADE_STATUS_FILTER_OPTIONS = [
  { value: '', label: 'Alle' },
  { value: 'active', label: 'Aktiv' },
  { value: 'partial', label: 'Teilverkauf' },
  { value: 'completed', label: 'Abgeschlossen' },
  { value: 'cancelled', label: 'Storniert' },
];

export const TRADE_PROFIT_FILTER_OPTIONS = [
  { value: '', label: 'Gewinn: alle' },
  { value: 'positive', label: 'Gewinn positiv' },
  { value: 'negative', label: 'Gewinn negativ' },
];

export const TRADE_SELL_PROGRESS_FILTER_OPTIONS = [
  { value: '', label: 'Alle' },
  { value: 'none', label: 'Noch nicht verkauft' },
  { value: 'partial', label: 'Teilverkauft' },
  { value: 'full', label: 'Vollständig verkauft' },
];

export const TRADE_POOL_INVESTORS_FILTER_OPTIONS = [
  { value: '', label: 'Alle' },
  { value: 'yes', label: 'Mit Pool-Investoren' },
  { value: 'no', label: 'Ohne Pool-Investoren' },
];

export const TRADE_RETURN_FILTER_OPTIONS = [
  { value: '', label: 'Alle' },
  { value: 'gt:200', label: '> 200 %' },
  { value: 'gt:150', label: '> 150 %' },
  { value: 'gt:100', label: '> 100 %' },
  { value: 'gt:80', label: '> 80 %' },
  { value: 'gt:60', label: '> 60 %' },
  { value: 'gt:40', label: '> 40 %' },
  { value: 'gt:20', label: '> 20 %' },
  { value: 'gt:0', label: '> 0 %' },
  { value: 'lt:-10', label: '< −10 %' },
  { value: 'lt:-30', label: '< −30 %' },
  { value: 'lt:-50', label: '< −50 %' },
  { value: 'lt:-70', label: '< −70 %' },
  { value: 'lt:-90', label: '< −90 %' },
  { value: 'custom', label: 'Benutzerdefiniert' },
];

export const TRADE_RETURN_CUSTOM_OP_OPTIONS = [
  { value: 'gt', label: '>' },
  { value: 'gte', label: '≥' },
  { value: 'lt', label: '<' },
  { value: 'lte', label: '≤' },
];

export type TradeReturnCustomOp = 'gt' | 'gte' | 'lt' | 'lte';

export function buildInvestmentFilterSelects(args: {
  status: string;
  returnSign: string;
  onStatusChange: (v: string) => void;
  onReturnSignChange: (v: string) => void;
}): AdminTableFilterSelect[] {
  return [
    {
      id: 'status',
      label: 'Status',
      value: args.status,
      options: INVESTMENT_STATUS_FILTER_OPTIONS,
      onChange: args.onStatusChange,
    },
    {
      id: 'returnSign',
      label: 'Buchwert-Rendite',
      value: args.returnSign,
      options: INVESTMENT_RETURN_FILTER_OPTIONS,
      onChange: args.onReturnSignChange,
    },
  ];
}

export function formatTraderFilterLabel(trader: {
  objectId: string;
  firstName?: string | null;
  lastName?: string | null;
  username?: string | null;
  email?: string | null;
}): string {
  const name = [trader.firstName, trader.lastName].filter(Boolean).join(' ').trim();
  return name || trader.username || trader.email || trader.objectId;
}

export function buildTraderFilterOptions(
  traders: {
    objectId: string;
    firstName?: string | null;
    lastName?: string | null;
    username?: string | null;
    email?: string | null;
  }[],
): { value: string; label: string }[] {
  const options = traders
    .map((trader) => ({
      value: trader.objectId,
      label: formatTraderFilterLabel(trader),
    }))
    .sort((a, b) => a.label.localeCompare(b.label, 'de'));
  return [{ value: '', label: 'Alle' }, ...options];
}

export function buildTradeFilterSelects(args: {
  traderId: string;
  status: string;
  returnFilter: string;
  profitSign: string;
  sellProgress: string;
  hasPoolInvestors: string;
  traderOptions?: { value: string; label: string }[];
  onTraderChange: (v: string) => void;
  onReturnFilterChange: (v: string) => void;
  onStatusChange: (v: string) => void;
  onProfitSignChange: (v: string) => void;
  onSellProgressChange: (v: string) => void;
  onHasPoolInvestorsChange: (v: string) => void;
}): AdminTableFilterSelect[] {
  return [
    {
      id: 'traderId',
      label: 'Trader',
      value: args.traderId,
      options: args.traderOptions ?? [{ value: '', label: 'Alle' }],
      onChange: args.onTraderChange,
    },
    {
      id: 'status',
      label: 'Status',
      value: args.status,
      options: TRADE_STATUS_FILTER_OPTIONS,
      onChange: args.onStatusChange,
    },
    {
      id: 'returnFilter',
      label: 'Rendite',
      value: args.returnFilter,
      options: TRADE_RETURN_FILTER_OPTIONS,
      onChange: args.onReturnFilterChange,
    },
    {
      id: 'profitSign',
      label: 'Gewinn',
      value: args.profitSign,
      options: TRADE_PROFIT_FILTER_OPTIONS,
      onChange: args.onProfitSignChange,
    },
    {
      id: 'sellProgress',
      label: 'Verkauf',
      value: args.sellProgress,
      options: TRADE_SELL_PROGRESS_FILTER_OPTIONS,
      onChange: args.onSellProgressChange,
    },
    {
      id: 'hasPoolInvestors',
      label: 'Pool',
      value: args.hasPoolInvestors,
      options: TRADE_POOL_INVESTORS_FILTER_OPTIONS,
      onChange: args.onHasPoolInvestorsChange,
    },
  ];
}

export function investmentListFilterParams(args: {
  search: string;
  status: string;
  returnSign: string;
}): Record<string, string> {
  const out: Record<string, string> = {};
  const search = args.search.trim();
  if (search) out.search = search;
  if (args.status) out.status = args.status;
  if (args.returnSign) out.returnSign = args.returnSign;
  return out;
}

export function tradeListFilterParams(args: {
  search: string;
  traderId: string;
  status: string;
  returnFilter: string;
  returnCustomOp?: TradeReturnCustomOp;
  returnCustomPct?: string;
  profitSign: string;
  sellProgress: string;
  hasPoolInvestors: string;
}): Record<string, string> {
  const out: Record<string, string> = {};
  const search = args.search.trim();
  if (search) out.search = search;
  if (args.traderId) out.traderId = args.traderId;
  if (args.status) out.status = args.status;
  if (args.returnFilter) {
    out.returnFilter = args.returnFilter;
    if (args.returnFilter === 'custom') {
      if (args.returnCustomOp) out.returnCustomOp = args.returnCustomOp;
      const pct = String(args.returnCustomPct ?? '').trim().replace(',', '.');
      if (pct) out.returnCustomPct = pct;
    }
  }
  if (args.profitSign) out.profitSign = args.profitSign;
  if (args.sellProgress) out.sellProgress = args.sellProgress;
  if (args.hasPoolInvestors) out.hasPoolInvestors = args.hasPoolInvestors;
  return out;
}
