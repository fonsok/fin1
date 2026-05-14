import { useState, useEffect, useMemo, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge, PaginationBar } from '../../components/ui';
import { SortableTh, nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { formatCurrency, formatDateTime, formatNumber } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';

import { adminBodyStrong, adminCaption, adminControlField, adminMuted, adminPrimary, adminSoft } from '../../utils/adminThemeClasses';
interface InvestmentSummary {
  investmentId: string;
  investmentNumber: string;
  investorId: string;
  investorName: string;
  traderId: string;
  traderName: string;
  amount: number;
  currentValue: number;
  grossProfit: number;
  returnPercentage: number;
  commission: number;
  status: string;
  createdAt: string;
}

interface TradeSummary {
  tradeId: string;
  tradeNumber: number;
  symbol: string;
  traderId: string;
  buyAmount: number;
  sellAmount: number;
  profit: number;
  status: string;
  investorIds: string[];
  createdAt: string;
}

interface SummaryData {
  totalInvestments: number;
  totalTrades: number;
  totalInvestedAmount: number;
  totalCurrentValue: number;
  totalGrossProfit: number;
  totalCommission: number;
  totalTradeVolume: number;
  totalTradeProfit: number;
  netReturn: number;
  commissionRate: number;
}

interface SummaryReportKpisResponse {
  summary: SummaryData;
  generatedAt: string;
}

interface PagedListResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

function dateParamsForRange(dateRange: 'all' | '30d' | '90d' | '1y'): Record<string, string> {
  const now = new Date();
  switch (dateRange) {
    case '30d':
      return { dateFrom: new Date(now.getTime() - 30 * 86400000).toISOString() };
    case '90d':
      return { dateFrom: new Date(now.getTime() - 90 * 86400000).toISOString() };
    case '1y':
      return { dateFrom: new Date(now.getTime() - 365 * 86400000).toISOString() };
    default:
      return {};
  }
}

type TabId = 'overview' | 'investments' | 'trades';

export function SummaryReportPage(): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const [dateRange, setDateRange] = useState<'all' | '30d' | '90d' | '1y'>('all');

  const dateParams = useMemo(() => dateParamsForRange(dateRange), [dateRange]);

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['summaryReport', dateRange],
    queryFn: () => cloudFunction<SummaryReportKpisResponse>('getSummaryReport', dateParams),
    staleTime: 60000,
  });

  const summary = data?.summary;
  const tabs: { id: TabId; label: string }[] = [
    { id: 'overview', label: 'Übersicht' },
    { id: 'investments', label: `Investments (${summary?.totalInvestments ?? 0})` },
    { id: 'trades', label: `Trades (${summary?.totalTrades ?? 0})` },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Summary Report</h1>
          <p className={clsx('mt-1', adminMuted(isDark))}>
            Aggregierte Übersicht aller Investments und Trades
            {data?.generatedAt && (
              <span className={clsx('ml-2 text-xs', adminCaption(isDark))}>
                ({formatDateTime(data.generatedAt)})
              </span>
            )}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value as typeof dateRange)}
            className={clsx(
              'border rounded-lg px-3 py-2 text-sm',
              adminControlField(isDark),
            )}
          >
            <option value="all">Alle Zeiten</option>
            <option value="30d">Letzte 30 Tage</option>
            <option value="90d">Letzte 90 Tage</option>
            <option value="1y">Letztes Jahr</option>
          </select>
          <Button variant="secondary" onClick={() => refetch()} disabled={isLoading}>
            {isLoading ? 'Laden...' : 'Aktualisieren'}
          </Button>
        </div>
      </div>

      {/* KPI Cards */}
      {summary && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <KPICard label="Investments" value={formatNumber(summary.totalInvestments)} sub={`Volumen: ${formatCurrency(summary.totalInvestedAmount)}`} />
          <KPICard label="Aktueller Wert" value={formatCurrency(summary.totalCurrentValue)} sub={`Rendite: ${summary.netReturn.toFixed(2)}%`} color={summary.netReturn >= 0 ? 'green' : 'red'} />
          <KPICard label="Brutto-Gewinn" value={formatCurrency(summary.totalGrossProfit)} sub={`Provision: ${formatCurrency(summary.totalCommission)}`} />
          <KPICard label="Trade-Volumen" value={formatCurrency(summary.totalTradeVolume)} sub={`Gewinn: ${formatCurrency(summary.totalTradeProfit)}`} />
        </div>
      )}

      {/* Tabs */}
      <div className={clsx('border-b', isDark ? 'border-slate-600' : 'border-gray-200')}>
        <nav className="flex space-x-4">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={clsx(
                'py-3 px-4 text-sm font-medium border-b-2 transition-colors',
                activeTab === tab.id
                  ? 'border-fin1-primary text-fin1-primary'
                  : isDark
                    ? 'border-transparent text-slate-400 hover:text-slate-200'
                    : 'border-transparent text-gray-500 hover:text-gray-700',
              )}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {isLoading ? (
        <Card>
          <div className={clsx('p-8 text-center', adminMuted(isDark))}>
            Daten werden geladen...
          </div>
        </Card>
      ) : activeTab === 'overview' && summary ? (
        <OverviewTab summary={summary} commissionRate={summary.commissionRate} />
      ) : activeTab === 'investments' ? (
        <InvestmentsTab dateParams={dateParams} dateRangeKey={dateRange} />
      ) : activeTab === 'trades' ? (
        <TradesTab dateParams={dateParams} dateRangeKey={dateRange} />
      ) : null}
    </div>
  );
}

function KPICard({ label, value, sub, color }: { label: string; value: string; sub?: string; color?: string }) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <Card>
      <div className="text-center">
        <p className={clsx('text-sm', adminMuted(isDark))}>{label}</p>
        <p
          className={clsx(
            'text-2xl font-bold mt-1',
            color === 'green' ? 'text-green-600' : color === 'red' ? 'text-red-600' : 'text-fin1-primary',
          )}
        >
          {value}
        </p>
        {sub && (
          <p className={clsx('text-xs mt-1', adminCaption(isDark))}>{sub}</p>
        )}
      </div>
    </Card>
  );
}

function OverviewTab({ summary, commissionRate }: { summary: SummaryData; commissionRate: number }) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const sectionTitle = clsx('text-md font-semibold mb-4', adminPrimary(isDark));

  const investmentRows = [
    { label: 'Anzahl Investments', value: formatNumber(summary.totalInvestments) },
    { label: 'Investiertes Kapital', value: formatCurrency(summary.totalInvestedAmount) },
    { label: 'Aktueller Gesamtwert', value: formatCurrency(summary.totalCurrentValue) },
    { label: 'Brutto-Gewinn', value: formatCurrency(summary.totalGrossProfit) },
    { label: 'Netto-Rendite', value: `${summary.netReturn.toFixed(2)}%` },
    { label: 'Provision (gesamt)', value: formatCurrency(summary.totalCommission) },
    { label: 'Provisionssatz', value: `${(commissionRate * 100).toFixed(0)}%` },
  ];

  const tradeRows = [
    { label: 'Anzahl Trades', value: formatNumber(summary.totalTrades) },
    { label: 'Handelsvolumen', value: formatCurrency(summary.totalTradeVolume) },
    { label: 'Trade-Gewinn', value: formatCurrency(summary.totalTradeProfit) },
    {
      label: 'Durchschn. Gewinn/Trade',
      value: formatCurrency(summary.totalTrades > 0 ? summary.totalTradeProfit / summary.totalTrades : 0),
    },
  ];

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <Card>
        <h3 className={sectionTitle}>Investment-Kennzahlen</h3>
        <div className="space-y-1">
          {investmentRows.map((row, index) => (
            <InfoRow key={row.label} label={row.label} value={row.value} index={index} />
          ))}
        </div>
      </Card>

      <Card>
        <h3 className={sectionTitle}>Trade-Kennzahlen</h3>
        <div className="space-y-1">
          {tradeRows.map((row, index) => (
            <InfoRow key={row.label} label={row.label} value={row.value} index={index} />
          ))}
        </div>
      </Card>
    </div>
  );
}

function InfoRow({ label, value, index }: { label: string; value: string; index: number }) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div
      className={clsx(
        'flex justify-between items-center py-2.5 px-3 rounded-lg gap-4',
        listRowStripeClasses(isDark, index, { hover: false }),
      )}
    >
      <span className={clsx('text-sm', adminSoft(isDark))}>{label}</span>
      <span className={clsx('text-sm font-medium text-right', adminPrimary(isDark))}>{value}</span>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const variants: Record<string, 'success' | 'warning' | 'neutral' | 'danger'> = {
    active: 'success',
    completed: 'success',
    pending: 'warning',
    unknown: 'neutral',
  };
  const labels: Record<string, string> = {
    active: 'Aktiv',
    completed: 'Abgeschlossen',
    pending: 'Ausstehend',
    unknown: 'Unbekannt',
  };
  return <Badge variant={variants[status] || 'neutral'}>{labels[status] || status}</Badge>;
}

function InvestmentsTab({
  dateParams,
  dateRangeKey,
}: {
  dateParams: Record<string, string>;
  dateRangeKey: string;
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  useEffect(() => {
    setPage(0);
  }, [dateRangeKey]);

  const onSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sortBy, sortOrder);
      setSortBy(next.sortBy);
      setSortOrder(next.sortOrder);
      setPage(0);
    },
    [sortBy, sortOrder],
  );

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['summaryReportInvestments', dateRangeKey, page, pageSize, sortBy, sortOrder],
    queryFn: () =>
      cloudFunction<PagedListResponse<InvestmentSummary>>('getSummaryReportInvestmentsPage', {
        ...dateParams,
        page,
        pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
  });

  const total = data?.total ?? 0;
  const items = data?.items ?? [];
  const thClass = clsx('px-4 py-3 text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark));

  if (isLoading && !data) {
    return (
      <Card>
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>
          Investments werden geladen...
        </div>
      </Card>
    );
  }

  if (total === 0) {
    return (
      <Card>
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>
          Keine Investments gefunden
        </div>
      </Card>
    );
  }

  return (
    <Card>
      <div className={clsx('p-3 border-b flex flex-wrap items-center gap-3 justify-between', isDark ? 'border-slate-600' : 'border-gray-100')}>
        <select
          value={pageSize}
          onChange={(e) => {
            setPageSize(Number(e.target.value));
            setPage(0);
          }}
          className={clsx(
            'border rounded-lg px-3 py-2 text-sm',
            adminControlField(isDark),
          )}
        >
          <option value={25}>25 / Seite</option>
          <option value={50}>50 / Seite</option>
          <option value={100}>100 / Seite</option>
        </select>
        <p className={clsx('text-sm', adminMuted(isDark))}>
          {isFetching ? 'Aktualisiere…' : `${formatNumber(total)} Investments gesamt (serverseitig)`}
        </p>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className={tableTheadSurfaceClasses(isDark)}>
            <tr>
              <th className={clsx(thClass, 'text-left')}>Nr.</th>
              <th className={clsx(thClass, 'text-left')}>Investor</th>
              <th className={clsx(thClass, 'text-left')}>Trader</th>
              <SortableTh
                label="Betrag"
                field="amount"
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onSort}
                align="right"
                className={clsx(thClass, 'text-right')}
              />
              <th className={clsx(thClass, 'text-right')}>Aktueller Wert</th>
              <th className={clsx(thClass, 'text-right')}>Rendite</th>
              <th className={clsx(thClass, 'text-right')}>Provision</th>
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
            {items.map((inv, index) => (
              <tr key={inv.investmentId} className={listRowStripeClasses(isDark, index)}>
                <td className={clsx('px-4 py-3 text-sm font-mono', adminBodyStrong(isDark))}>
                  {inv.investmentNumber}
                </td>
                <td className={clsx('px-4 py-3 text-sm', adminBodyStrong(isDark))}>
                  {inv.investorName}
                </td>
                <td className={clsx('px-4 py-3 text-sm', adminBodyStrong(isDark))}>
                  {inv.traderName}
                </td>
                <td className={clsx('px-4 py-3 text-sm text-right', adminBodyStrong(isDark))}>
                  {formatCurrency(inv.amount)}
                </td>
                <td className={clsx('px-4 py-3 text-sm text-right', adminBodyStrong(isDark))}>
                  {formatCurrency(inv.currentValue)}
                </td>
                <td
                  className={clsx(
                    'px-4 py-3 text-sm text-right font-medium',
                    inv.returnPercentage >= 0
                      ? isDark
                        ? 'text-green-400'
                        : 'text-green-600'
                      : isDark
                        ? 'text-red-400'
                        : 'text-red-600',
                  )}
                >
                  {inv.returnPercentage.toFixed(2)}%
                </td>
                <td className={clsx('px-4 py-3 text-sm text-right', adminBodyStrong(isDark))}>
                  {formatCurrency(inv.commission)}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={inv.status} />
                </td>
                <td className={clsx('px-4 py-3 text-sm', adminMuted(isDark))}>
                  {formatDateTime(inv.createdAt)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <PaginationBar
        page={page}
        pageSize={pageSize}
        total={total}
        itemLabel="Investments"
        isDark={isDark}
        onPageChange={setPage}
      />
    </Card>
  );
}

function TradesTab({
  dateParams,
  dateRangeKey,
}: {
  dateParams: Record<string, string>;
  dateRangeKey: string;
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  useEffect(() => {
    setPage(0);
  }, [dateRangeKey]);

  const onSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sortBy, sortOrder);
      setSortBy(next.sortBy);
      setSortOrder(next.sortOrder);
      setPage(0);
    },
    [sortBy, sortOrder],
  );

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['summaryReportTrades', dateRangeKey, page, pageSize, sortBy, sortOrder],
    queryFn: () =>
      cloudFunction<PagedListResponse<TradeSummary>>('getSummaryReportTradesPage', {
        ...dateParams,
        page,
        pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
  });

  const total = data?.total ?? 0;
  const items = data?.items ?? [];
  const thClass = clsx('px-4 py-3 text-xs font-medium uppercase', tableHeaderCellTextClasses(isDark));

  if (isLoading && !data) {
    return (
      <Card>
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>
          Trades werden geladen...
        </div>
      </Card>
    );
  }

  if (total === 0) {
    return (
      <Card>
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>
          Keine Trades gefunden
        </div>
      </Card>
    );
  }

  return (
    <Card>
      <div className={clsx('p-3 border-b flex flex-wrap items-center gap-3 justify-between', isDark ? 'border-slate-600' : 'border-gray-100')}>
        <select
          value={pageSize}
          onChange={(e) => {
            setPageSize(Number(e.target.value));
            setPage(0);
          }}
          className={clsx(
            'border rounded-lg px-3 py-2 text-sm',
            adminControlField(isDark),
          )}
        >
          <option value={25}>25 / Seite</option>
          <option value={50}>50 / Seite</option>
          <option value={100}>100 / Seite</option>
        </select>
        <p className={clsx('text-sm', adminMuted(isDark))}>
          {isFetching ? 'Aktualisiere…' : `${formatNumber(total)} Trades gesamt (serverseitig)`}
        </p>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className={tableTheadSurfaceClasses(isDark)}>
            <tr>
              <SortableTh
                label="Nr."
                field="tradeNumber"
                sortBy={sortBy}
                sortOrder={sortOrder}
                onSort={onSort}
                className={clsx(thClass, 'text-left')}
              />
              <th className={clsx(thClass, 'text-left')}>Symbol</th>
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
              <tr key={trade.tradeId} className={listRowStripeClasses(isDark, index)}>
                <td className={clsx('px-4 py-3 text-sm font-mono', adminBodyStrong(isDark))}>
                  {String(trade.tradeNumber).padStart(3, '0')}
                </td>
                <td className={clsx('px-4 py-3 text-sm font-medium', adminPrimary(isDark))}>
                  {trade.symbol}
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
                  {trade.investorIds.length}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={trade.status} />
                </td>
                <td className={clsx('px-4 py-3 text-sm', adminMuted(isDark))}>
                  {formatDateTime(trade.createdAt)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <PaginationBar
        page={page}
        pageSize={pageSize}
        total={total}
        itemLabel="Trades"
        isDark={isDark}
        onPageChange={setPage}
      />
    </Card>
  );
}
