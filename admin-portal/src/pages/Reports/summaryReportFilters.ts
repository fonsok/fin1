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

export function buildTradeFilterSelects(args: {
  status: string;
  profitSign: string;
  sellProgress: string;
  hasPoolInvestors: string;
  onStatusChange: (v: string) => void;
  onProfitSignChange: (v: string) => void;
  onSellProgressChange: (v: string) => void;
  onHasPoolInvestorsChange: (v: string) => void;
}): AdminTableFilterSelect[] {
  return [
    {
      id: 'status',
      label: 'Status',
      value: args.status,
      options: TRADE_STATUS_FILTER_OPTIONS,
      onChange: args.onStatusChange,
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
  status: string;
  profitSign: string;
  sellProgress: string;
  hasPoolInvestors: string;
}): Record<string, string> {
  const out: Record<string, string> = {};
  const search = args.search.trim();
  if (search) out.search = search;
  if (args.status) out.status = args.status;
  if (args.profitSign) out.profitSign = args.profitSign;
  if (args.sellProgress) out.sellProgress = args.sellProgress;
  if (args.hasPoolInvestors) out.hasPoolInvestors = args.hasPoolInvestors;
  return out;
}
