import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge, getStatusVariant } from '../../components/ui';
import { formatCurrency, formatDateTime } from '../../utils/format';
import { StatCard } from './components/StatCard';
import { CorrectionModal } from './components/CorrectionModal';
import { mockStats, mockRoundingDiffs, mockCorrections } from './mockData';
import type { FinancialStats, RoundingDifference, CorrectionRequest } from './types';

export function FinanceDashboardPage(): JSX.Element {
  const [showCorrectionModal, setShowCorrectionModal] = useState(false);

  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['financialDashboard'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ stats: FinancialStats }>('getFinancialDashboard', {});
        console.log('📊 Finance Dashboard loaded:', result.stats);
        return result.stats;
      } catch (error) {
        console.error('📊 Finance Dashboard error, using mock data:', error);
        return mockStats;
      }
    },
    staleTime: 0, // Always refetch
    refetchOnMount: 'always',
  });

  const { data: roundingDiffs } = useQuery({
    queryKey: ['roundingDifferences'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ differences: RoundingDifference[] }>('getRoundingDifferences', {});
        return result.differences;
      } catch {
        return mockRoundingDiffs;
      }
    },
    initialData: mockRoundingDiffs,
  });

  const { data: corrections } = useQuery({
    queryKey: ['correctionRequests'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ corrections: CorrectionRequest[] }>('getCorrectionRequests', {});
        return result.corrections;
      } catch {
        return mockCorrections;
      }
    },
    initialData: mockCorrections,
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Finanzen</h1>
          <p className="text-gray-500 mt-1">Finanzübersicht, Korrekturen und Rundungsdifferenzen</p>
        </div>
        <Button onClick={() => setShowCorrectionModal(true)}>+ Korrektur anlegen</Button>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statsLoading ? (
          <>
            <StatCard title="Gesamtumsatz" value="Laden..." subtitle="Alle Zeiten" icon="💰" />
            <StatCard title="Monatsumsatz" value="Laden..." subtitle="Februar 2026" icon="📈" />
            <StatCard title="Gebühren (Monat)" value="Laden..." subtitle="Februar 2026" icon="📊" />
            <StatCard title="Investments" value="Laden..." subtitle="Aktives Volumen" icon="🏦" />
          </>
        ) : (
          <>
            <StatCard title="Gesamtumsatz" value={formatCurrency(stats?.totalRevenue ?? 0)} subtitle="Alle Zeiten" icon="💰" />
            <StatCard title="Monatsumsatz" value={formatCurrency(stats?.monthlyRevenue ?? 0)} subtitle="Februar 2026" icon="📈" trend="+12%" />
            <StatCard title="Gebühren (Monat)" value={formatCurrency(stats?.monthlyFees ?? 0)} subtitle="Februar 2026" icon="📊" />
            <StatCard title="Investments" value={formatCurrency(stats?.totalInvestments ?? 0)} subtitle="Aktives Volumen" icon="🏦" />
          </>
        )}
      </div>

      {/* Alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="p-4 bg-amber-50 border-amber-200">
          <div className="flex items-center gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <p className="font-semibold text-amber-800">{stats?.pendingCorrections ?? 0} ausstehende Korrekturen</p>
              <p className="text-sm text-amber-600">Erfordern 4-Augen-Freigabe</p>
            </div>
          </div>
        </Card>
        <Card className="p-4 bg-blue-50 border-blue-200">
          <div className="flex items-center gap-3">
            <span className="text-2xl">🔢</span>
            <div>
              <p className="font-semibold text-blue-800">{stats?.openRoundingDiffs ?? 0} offene Rundungsdifferenzen</p>
              <p className="text-sm text-blue-600">Müssen geprüft werden</p>
            </div>
          </div>
        </Card>
      </div>

      {/* Two Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Rounding Differences */}
        <RoundingDiffsList differences={roundingDiffs} />

        {/* Correction Requests */}
        <CorrectionsList corrections={corrections} />
      </div>

      {/* Correction Modal */}
      {showCorrectionModal && <CorrectionModal onClose={() => setShowCorrectionModal(false)} />}
    </div>
  );
}

function RoundingDiffsList({ differences }: { differences: RoundingDifference[] }): JSX.Element {
  return (
    <Card>
      <div className="p-4 border-b border-gray-100">
        <h2 className="text-lg font-semibold">Rundungsdifferenzen</h2>
      </div>
      <div className="divide-y divide-gray-100">
        {differences.map((diff) => (
          <div key={diff.objectId} className="p-4 flex items-center justify-between">
            <div>
              <p className="font-medium text-gray-900">{diff.transactionId}</p>
              <p className="text-sm text-gray-500">{formatDateTime(diff.createdAt)}</p>
            </div>
            <div className="flex items-center gap-3">
              <span className={`font-mono ${diff.amount >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {diff.amount >= 0 ? '+' : ''}{diff.amount.toFixed(2)} {diff.currency}
              </span>
              <Badge variant={getStatusVariant(diff.status)}>
                {diff.status === 'open' ? 'Offen' : diff.status === 'reviewed' ? 'Geprüft' : 'Erledigt'}
              </Badge>
            </div>
          </div>
        ))}
      </div>
      <div className="p-4 border-t border-gray-100">
        <Button variant="ghost" className="w-full">Alle anzeigen →</Button>
      </div>
    </Card>
  );
}

function CorrectionsList({ corrections }: { corrections: CorrectionRequest[] }): JSX.Element {
  const getStatusBadge = (status: string): 'warning' | 'success' | 'danger' => {
    if (status === 'pending') return 'warning';
    if (status === 'approved') return 'success';
    return 'danger';
  };

  const getStatusLabel = (status: string): string => {
    if (status === 'pending') return 'Ausstehend';
    if (status === 'approved') return 'Genehmigt';
    return 'Abgelehnt';
  };

  const getTypeLabel = (type: string): string => {
    if (type === 'fee_refund') return 'Gebührenerstattung';
    if (type === 'investment_adjustment') return 'Investment-Korrektur';
    return type;
  };

  return (
    <Card>
      <div className="p-4 border-b border-gray-100">
        <h2 className="text-lg font-semibold">Korrekturbuchungen</h2>
      </div>
      <div className="divide-y divide-gray-100">
        {corrections.map((corr) => (
          <div key={corr.objectId} className="p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="font-medium text-gray-900">{getTypeLabel(corr.type)}</span>
              <Badge variant={getStatusBadge(corr.status)}>{getStatusLabel(corr.status)}</Badge>
            </div>
            <p className="text-sm text-gray-600 mb-1">{corr.reason}</p>
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-500">{formatDateTime(corr.createdAt)}</span>
              <span className="font-semibold text-fin1-primary">{formatCurrency(corr.amount)}</span>
            </div>
          </div>
        ))}
      </div>
      <div className="p-4 border-t border-gray-100">
        <Button variant="ghost" className="w-full">Alle anzeigen →</Button>
      </div>
    </Card>
  );
}
