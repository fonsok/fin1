import { useState, useEffect, useMemo, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction, searchUsers } from '../../api/admin';
import { AdminUserDetailLink } from '../../components/AdminUserDetailLink';
import { Card, Button, Badge, PaginationBar, Input } from '../../components/ui';
import { useDebounce } from '../../hooks/useDebounce';
import { useDateRangeFilter } from '../../hooks/useDateRangeFilter';
import { AdminTableFilterBar } from '../../components/filters/AdminTableFilterBar';
import { DateRangeFilterFields } from '../../components/filters/DateRangeFilterFields';
import { isDateRangeFilterActive } from '../../utils/dateRangePreset';
import { SortableTh, nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { formatCurrency, formatDateTime, formatNumber } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';

import {
  adminBodyStrong,
  adminBorderChrome,
  adminBorderChromeSoft,
  adminCaption,
  adminControlField,
  adminMuted,
  adminPrimary,
  adminSoft,
  adminStrong,
} from '../../utils/adminThemeClasses';
import {
  SummaryReportTradesTable,
  type SummaryReportTradeRow,
} from './SummaryReportTradesTable';
import { SummaryReportSearchIndexStatusButton } from './SummaryReportSearchIndexStatusButton';
import {
  buildInvestmentFilterSelects,
  buildTradeFilterSelects,
  buildTraderFilterOptions,
  investmentListFilterParams,
  tradeListFilterParams,
  TRADE_RETURN_CUSTOM_OP_OPTIONS,
  type TradeReturnCustomOp,
} from './summaryReportFilters';

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

type TabId = 'overview' | 'investments' | 'trades';

export function SummaryReportPage(): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const overviewDate = useDateRangeFilter('all');

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['summaryReport', overviewDate.apiParams],
    queryFn: () =>
      cloudFunction<SummaryReportKpisResponse>('getSummaryReport', overviewDate.apiParams),
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
        <div className="flex flex-wrap gap-2">
          <SummaryReportSearchIndexStatusButton />
          <Button variant="secondary" onClick={() => refetch()} disabled={isLoading}>
            {isLoading ? 'Laden...' : 'Aktualisieren'}
          </Button>
        </div>
      </div>

      {activeTab === 'overview' && (
        <Card>
          <div className="p-4 flex flex-col sm:flex-row gap-4 items-end flex-wrap">
            <DateRangeFilterFields
              preset={overviewDate.datePreset}
              dateFromInput={overviewDate.dateFromInput}
              dateToInput={overviewDate.dateToInput}
              onPresetChange={(preset) => {
                overviewDate.onPresetChange(preset);
              }}
              onDateFromChange={overviewDate.setDateFromInput}
              onDateToChange={overviewDate.setDateToInput}
            />
            {isDateRangeFilterActive(
              overviewDate.datePreset,
              overviewDate.dateFromInput,
              overviewDate.dateToInput,
            ) && (
              <Button variant="ghost" onClick={overviewDate.resetDateRange}>
                Zeitraum zurücksetzen
              </Button>
            )}
          </div>
        </Card>
      )}

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
      <div className={clsx('border-b', adminBorderChrome(isDark))}>
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
        <InvestmentsTab />
      ) : activeTab === 'trades' ? (
        <TradesTab />
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
  const variants: Record<string, 'success' | 'warning' | 'neutral' | 'danger' | 'info'> = {
    active: 'success',
    executing: 'info',
    reserved: 'warning',
    paused: 'warning',
    closing: 'warning',
    completed: 'success',
    cancelled: 'danger',
    pending: 'warning',
    unknown: 'neutral',
  };
  const labels: Record<string, string> = {
    active: 'Aktiv',
    executing: 'Ausführend',
    reserved: 'Reserviert',
    paused: 'Pausiert',
    closing: 'Schließend',
    completed: 'Abgeschlossen',
    cancelled: 'Storniert',
    pending: 'Ausstehend',
    unknown: 'Unbekannt',
  };
  return <Badge variant={variants[status] || 'neutral'}>{labels[status] || status}</Badge>;
}

function InvestmentsTab() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [returnSignFilter, setReturnSignFilter] = useState('');
  const debouncedSearch = useDebounce(searchQuery);
  const dateFilter = useDateRangeFilter('all');

  const listFilters = useMemo(
    () => ({
      ...dateFilter.apiParams,
      ...investmentListFilterParams({
        search: debouncedSearch,
        status: statusFilter,
        returnSign: returnSignFilter,
      }),
    }),
    [dateFilter.apiParams, debouncedSearch, statusFilter, returnSignFilter],
  );

  const hasActiveFilters = Boolean(
    debouncedSearch.trim()
      || statusFilter
      || returnSignFilter
      || dateFilter.hasActiveDateRange,
  );

  const resetFilters = useCallback(() => {
    setSearchQuery('');
    setStatusFilter('');
    setReturnSignFilter('');
    dateFilter.resetDateRange();
    setPage(0);
  }, [dateFilter]);

  useEffect(() => {
    setPage(0);
  }, [listFilters]);

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
    queryKey: ['summaryReportInvestments', page, pageSize, sortBy, sortOrder, listFilters],
    queryFn: () =>
      cloudFunction<PagedListResponse<InvestmentSummary>>('getSummaryReportInvestmentsPage', {
        ...listFilters,
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

  const filterSelects = buildInvestmentFilterSelects({
    status: statusFilter,
    returnSign: returnSignFilter,
    onStatusChange: setStatusFilter,
    onReturnSignChange: setReturnSignFilter,
  });

  const filterBar = (
    <AdminTableFilterBar
      searchPlaceholder="Nr., Investor oder Trader…"
      searchValue={searchQuery}
      onSearchChange={setSearchQuery}
      selects={filterSelects}
      dateRange={{
        preset: dateFilter.datePreset,
        dateFromInput: dateFilter.dateFromInput,
        dateToInput: dateFilter.dateToInput,
        onPresetChange: (preset) => {
          dateFilter.onPresetChange(preset);
          setPage(0);
        },
        onDateFromChange: (v) => {
          dateFilter.setDateFromInput(v);
          setPage(0);
        },
        onDateToChange: (v) => {
          dateFilter.setDateToInput(v);
          setPage(0);
        },
      }}
      pageSize={{
        value: pageSize,
        onChange: (size) => {
          setPageSize(size);
          setPage(0);
        },
      }}
      hasActiveFilters={hasActiveFilters}
      onReset={resetFilters}
      resultHint={
        isFetching
          ? 'Aktualisiere…'
          : `${formatNumber(total)} Investments (gefiltert, serverseitig)`
      }
    />
  );

  if (isLoading && !data) {
    return (
      <Card>
        <div className={clsx('p-4 border-b', adminBorderChromeSoft(isDark))}>{filterBar}</div>
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>
          Investments werden geladen...
        </div>
      </Card>
    );
  }

  return (
    <Card>
      <div className={clsx('p-4 border-b', adminBorderChromeSoft(isDark))}>{filterBar}</div>
      {total === 0 ? (
        <div className={clsx('p-8 text-center', adminMuted(isDark))}>
          {hasActiveFilters
            ? 'Keine Investments für die aktuelle Suche oder Filter.'
            : 'Keine Investments gefunden'}
        </div>
      ) : (
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
                  <AdminUserDetailLink
                    userId={inv.investorId}
                    label={inv.investorName}
                    isDark={isDark}
                  />
                </td>
                <td className={clsx('px-4 py-3 text-sm', adminBodyStrong(isDark))}>
                  <AdminUserDetailLink
                    userId={inv.traderId}
                    label={inv.traderName}
                    isDark={isDark}
                  />
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
      )}
      {total > 0 && (
        <PaginationBar
          page={page}
          pageSize={pageSize}
          total={total}
          itemLabel="Investments"
          isDark={isDark}
          onPageChange={setPage}
        />
      )}
    </Card>
  );
}

function TradesTab() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');
  const [searchQuery, setSearchQuery] = useState('');
  const [traderFilter, setTraderFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [returnFilter, setReturnFilter] = useState('');
  const [returnCustomOp, setReturnCustomOp] = useState<TradeReturnCustomOp>('gt');
  const [returnCustomPct, setReturnCustomPct] = useState('');
  const [profitSignFilter, setProfitSignFilter] = useState('');
  const [sellProgressFilter, setSellProgressFilter] = useState('');
  const [hasPoolInvestorsFilter, setHasPoolInvestorsFilter] = useState('');
  const debouncedSearch = useDebounce(searchQuery);
  const debouncedReturnCustomPct = useDebounce(returnCustomPct);
  const dateFilter = useDateRangeFilter('all');

  const { data: traderOptionsData } = useQuery({
    queryKey: ['summaryReportTraderFilterOptions'],
    queryFn: () =>
      searchUsers({
        role: 'trader',
        limit: 200,
        sortBy: 'lastName',
        sortOrder: 'asc',
      }),
    staleTime: 300_000,
  });
  const traderFilterOptions = useMemo(
    () => buildTraderFilterOptions(traderOptionsData?.users ?? []),
    [traderOptionsData?.users],
  );

  const listFilters = useMemo(
    () => ({
      ...dateFilter.apiParams,
      ...tradeListFilterParams({
        search: debouncedSearch,
        traderId: traderFilter,
        status: statusFilter,
        returnFilter,
        returnCustomOp,
        returnCustomPct: debouncedReturnCustomPct,
        profitSign: profitSignFilter,
        sellProgress: sellProgressFilter,
        hasPoolInvestors: hasPoolInvestorsFilter,
      }),
    }),
    [
      dateFilter.apiParams,
      debouncedSearch,
      traderFilter,
      statusFilter,
      returnFilter,
      returnCustomOp,
      debouncedReturnCustomPct,
      profitSignFilter,
      sellProgressFilter,
      hasPoolInvestorsFilter,
    ],
  );

  const hasActiveReturnFilter = Boolean(
    (returnFilter && returnFilter !== 'custom')
      || (returnFilter === 'custom' && debouncedReturnCustomPct.trim()),
  );

  const hasActiveFilters = Boolean(
    debouncedSearch.trim()
      || traderFilter
      || statusFilter
      || hasActiveReturnFilter
      || profitSignFilter
      || sellProgressFilter
      || hasPoolInvestorsFilter
      || dateFilter.hasActiveDateRange,
  );

  const resetFilters = useCallback(() => {
    setSearchQuery('');
    setTraderFilter('');
    setStatusFilter('');
    setReturnFilter('');
    setReturnCustomOp('gt');
    setReturnCustomPct('');
    setProfitSignFilter('');
    setSellProgressFilter('');
    setHasPoolInvestorsFilter('');
    dateFilter.resetDateRange();
    setPage(0);
  }, [dateFilter]);

  useEffect(() => {
    setPage(0);
  }, [listFilters]);

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
    queryKey: ['summaryReportTrades', page, pageSize, sortBy, sortOrder, listFilters],
    queryFn: () =>
      cloudFunction<PagedListResponse<SummaryReportTradeRow>>('getSummaryReportTradesPage', {
        ...listFilters,
        page,
        pageSize,
        sortBy,
        sortOrder,
      }),
    staleTime: 30_000,
  });

  const total = data?.total ?? 0;
  const items = data?.items ?? [];

  const toolbar = (
    <AdminTableFilterBar
      searchPlaceholder="Symbol, Trade-Nr., Trader…"
      searchValue={searchQuery}
      onSearchChange={setSearchQuery}
      selects={buildTradeFilterSelects({
        traderId: traderFilter,
        traderOptions: traderFilterOptions,
        status: statusFilter,
        returnFilter,
        profitSign: profitSignFilter,
        sellProgress: sellProgressFilter,
        hasPoolInvestors: hasPoolInvestorsFilter,
        onTraderChange: setTraderFilter,
        onReturnFilterChange: setReturnFilter,
        onStatusChange: setStatusFilter,
        onProfitSignChange: setProfitSignFilter,
        onSellProgressChange: setSellProgressFilter,
        onHasPoolInvestorsChange: setHasPoolInvestorsFilter,
      })}
      trailingContent={
        returnFilter === 'custom' ? (
          <div className="flex flex-wrap gap-2 items-end min-w-[14rem]">
            <div className="min-w-[5rem]">
              <label className={clsx('block text-sm font-medium mb-1', adminStrong(isDark))}>
                Vergleich
              </label>
              <select
                value={returnCustomOp}
                onChange={(e) => {
                  setReturnCustomOp(e.target.value as TradeReturnCustomOp);
                  setPage(0);
                }}
                className={clsx(
                  'w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-fin1-primary',
                  adminControlField(isDark),
                )}
              >
                {TRADE_RETURN_CUSTOM_OP_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="min-w-[8rem] flex-1">
              <label className={clsx('block text-sm font-medium mb-1', adminStrong(isDark))}>
                Rendite %
              </label>
              <Input
                type="number"
                inputMode="decimal"
                placeholder="z. B. 25"
                value={returnCustomPct}
                onChange={(e) => {
                  setReturnCustomPct(e.target.value);
                  setPage(0);
                }}
              />
            </div>
          </div>
        ) : null
      }
      dateRange={{
        preset: dateFilter.datePreset,
        dateFromInput: dateFilter.dateFromInput,
        dateToInput: dateFilter.dateToInput,
        onPresetChange: (preset) => {
          dateFilter.onPresetChange(preset);
          setPage(0);
        },
        onDateFromChange: (v) => {
          dateFilter.setDateFromInput(v);
          setPage(0);
        },
        onDateToChange: (v) => {
          dateFilter.setDateToInput(v);
          setPage(0);
        },
      }}
      pageSize={{
        value: pageSize,
        onChange: (size) => {
          setPageSize(size);
          setPage(0);
        },
      }}
      hasActiveFilters={hasActiveFilters}
      onReset={resetFilters}
      resultHint={
        isFetching
          ? 'Aktualisiere…'
          : `${formatNumber(total)} Trades (gefiltert, serverseitig)`
      }
    />
  );

  return (
    <SummaryReportTradesTable
      items={items}
      total={total}
      page={page}
      pageSize={pageSize}
      sortBy={sortBy}
      sortOrder={sortOrder}
      isLoading={isLoading && !data}
      isDark={isDark}
      toolbar={toolbar}
      emptyMessage={
        hasActiveFilters
          ? 'Keine Trades für die aktuelle Suche oder Filter.'
          : 'Keine Trades gefunden'
      }
      onPageChange={setPage}
      onSort={onSort}
    />
  );
}
