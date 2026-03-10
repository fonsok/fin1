import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge } from '../../components/ui';
import { formatCurrency, formatDateTime, formatNumber } from '../../utils/format';

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

interface SummaryReportResponse {
  summary: SummaryData;
  investments: InvestmentSummary[];
  trades: TradeSummary[];
  generatedAt: string;
}

type TabId = 'overview' | 'investments' | 'trades';

export function SummaryReportPage(): JSX.Element {
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const [dateRange, setDateRange] = useState<'all' | '30d' | '90d' | '1y'>('all');

  const dateParams = (() => {
    const now = new Date();
    switch (dateRange) {
      case '30d': return { dateFrom: new Date(now.getTime() - 30 * 86400000).toISOString() };
      case '90d': return { dateFrom: new Date(now.getTime() - 90 * 86400000).toISOString() };
      case '1y': return { dateFrom: new Date(now.getTime() - 365 * 86400000).toISOString() };
      default: return {};
    }
  })();

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['summaryReport', dateRange],
    queryFn: () => cloudFunction<SummaryReportResponse>('getSummaryReport', dateParams),
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
          <h1 className="text-2xl font-bold text-gray-900">Summary Report</h1>
          <p className="text-gray-500 mt-1">
            Aggregierte Übersicht aller Investments und Trades
            {data?.generatedAt && <span className="ml-2 text-xs">({formatDateTime(data.generatedAt)})</span>}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value as typeof dateRange)}
            className="border border-gray-300 rounded-lg px-3 py-2 text-sm"
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
      <div className="border-b border-gray-200">
        <nav className="flex space-x-4">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`py-3 px-4 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.id
                  ? 'border-fin1-primary text-fin1-primary'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {isLoading ? (
        <Card><div className="p-8 text-center text-gray-500">Daten werden geladen...</div></Card>
      ) : activeTab === 'overview' && summary ? (
        <OverviewTab summary={summary} commissionRate={summary.commissionRate} />
      ) : activeTab === 'investments' ? (
        <InvestmentsTab investments={data?.investments || []} />
      ) : activeTab === 'trades' ? (
        <TradesTab trades={data?.trades || []} />
      ) : null}
    </div>
  );
}

function KPICard({ label, value, sub, color }: { label: string; value: string; sub?: string; color?: string }) {
  return (
    <Card>
      <div className="text-center">
        <p className="text-sm text-gray-500">{label}</p>
        <p className={`text-2xl font-bold mt-1 ${color === 'green' ? 'text-green-600' : color === 'red' ? 'text-red-600' : 'text-fin1-primary'}`}>
          {value}
        </p>
        {sub && <p className="text-xs text-gray-400 mt-1">{sub}</p>}
      </div>
    </Card>
  );
}

function OverviewTab({ summary, commissionRate }: { summary: SummaryData; commissionRate: number }) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <Card>
        <h3 className="text-md font-semibold mb-4">Investment-Kennzahlen</h3>
        <div className="space-y-3">
          <InfoRow label="Anzahl Investments" value={formatNumber(summary.totalInvestments)} />
          <InfoRow label="Investiertes Kapital" value={formatCurrency(summary.totalInvestedAmount)} />
          <InfoRow label="Aktueller Gesamtwert" value={formatCurrency(summary.totalCurrentValue)} />
          <InfoRow label="Brutto-Gewinn" value={formatCurrency(summary.totalGrossProfit)} />
          <InfoRow label="Netto-Rendite" value={`${summary.netReturn.toFixed(2)}%`} />
          <InfoRow label="Provision (gesamt)" value={formatCurrency(summary.totalCommission)} />
          <InfoRow label="Provisionssatz" value={`${(commissionRate * 100).toFixed(0)}%`} />
        </div>
      </Card>

      <Card>
        <h3 className="text-md font-semibold mb-4">Trade-Kennzahlen</h3>
        <div className="space-y-3">
          <InfoRow label="Anzahl Trades" value={formatNumber(summary.totalTrades)} />
          <InfoRow label="Handelsvolumen" value={formatCurrency(summary.totalTradeVolume)} />
          <InfoRow label="Trade-Gewinn" value={formatCurrency(summary.totalTradeProfit)} />
          <InfoRow
            label="Durchschn. Gewinn/Trade"
            value={formatCurrency(summary.totalTrades > 0 ? summary.totalTradeProfit / summary.totalTrades : 0)}
          />
        </div>
      </Card>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between items-center py-1 border-b border-gray-50 last:border-0">
      <span className="text-sm text-gray-600">{label}</span>
      <span className="text-sm font-medium text-gray-900">{value}</span>
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

function InvestmentsTab({ investments }: { investments: InvestmentSummary[] }) {
  if (investments.length === 0) {
    return <Card><div className="p-8 text-center text-gray-500">Keine Investments gefunden</div></Card>;
  }

  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nr.</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Investor</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Trader</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Betrag</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Aktueller Wert</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Rendite</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Provision</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Datum</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {investments.map((inv) => (
              <tr key={inv.investmentId} className="hover:bg-gray-50">
                <td className="px-4 py-3 text-sm font-mono">{inv.investmentNumber}</td>
                <td className="px-4 py-3 text-sm">{inv.investorName}</td>
                <td className="px-4 py-3 text-sm">{inv.traderName}</td>
                <td className="px-4 py-3 text-sm text-right">{formatCurrency(inv.amount)}</td>
                <td className="px-4 py-3 text-sm text-right">{formatCurrency(inv.currentValue)}</td>
                <td className={`px-4 py-3 text-sm text-right font-medium ${inv.returnPercentage >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {inv.returnPercentage.toFixed(2)}%
                </td>
                <td className="px-4 py-3 text-sm text-right">{formatCurrency(inv.commission)}</td>
                <td className="px-4 py-3"><StatusBadge status={inv.status} /></td>
                <td className="px-4 py-3 text-sm text-gray-500">{formatDateTime(inv.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function TradesTab({ trades }: { trades: TradeSummary[] }) {
  if (trades.length === 0) {
    return <Card><div className="p-8 text-center text-gray-500">Keine Trades gefunden</div></Card>;
  }

  return (
    <Card>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nr.</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Symbol</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Kauf</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Verkauf</th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Gewinn</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Investoren</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Datum</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {trades.map((trade) => (
              <tr key={trade.tradeId} className="hover:bg-gray-50">
                <td className="px-4 py-3 text-sm font-mono">{String(trade.tradeNumber).padStart(3, '0')}</td>
                <td className="px-4 py-3 text-sm font-medium">{trade.symbol}</td>
                <td className="px-4 py-3 text-sm text-right">{formatCurrency(trade.buyAmount)}</td>
                <td className="px-4 py-3 text-sm text-right">{formatCurrency(trade.sellAmount)}</td>
                <td className={`px-4 py-3 text-sm text-right font-medium ${trade.profit >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {formatCurrency(trade.profit)}
                </td>
                <td className="px-4 py-3 text-sm text-center">{trade.investorIds.length}</td>
                <td className="px-4 py-3"><StatusBadge status={trade.status} /></td>
                <td className="px-4 py-3 text-sm text-gray-500">{formatDateTime(trade.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
