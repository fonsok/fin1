import clsx from 'clsx';
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge, getStatusVariant } from '../../components/ui';
import { useTheme } from '../../context/ThemeContext';
import { formatCurrency, formatDateTime } from '../../utils/format';
import { emptyListPlaceholderClasses, listRowStripeClasses, tableBodyDivideClasses } from '../../utils/tableStriping';
import { StatCard } from './components/StatCard';
import { CorrectionModal } from './components/CorrectionModal';
import { mockStats, mockRoundingDiffs, mockCorrections } from './mockData';
import type { FinancialStats, RoundingDifference, CorrectionRequest } from './types';

import { adminBorderChromeSoft, adminMuted, adminPrimary, adminSoft } from '../../utils/adminThemeClasses';
export function FinanceDashboardPage(): JSX.Element {
  const [showCorrectionModal, setShowCorrectionModal] = useState(false);
  const { theme } = useTheme();
  const isDark = theme === 'dark';

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
          <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Finanzen</h1>
          <p className={clsx('mt-1', adminMuted(isDark))}>
            Finanzübersicht, Korrekturen und Rundungsdifferenzen
          </p>
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
        <Card
          className={clsx(
            'p-4 border',
            isDark ? 'bg-slate-800/90 border-amber-500/50' : 'bg-amber-50 border-amber-200',
          )}
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <p className={clsx('font-semibold', isDark ? 'text-amber-200' : 'text-amber-900')}>
                {stats?.pendingCorrections ?? 0} ausstehende Korrekturen
              </p>
              <p className={clsx('text-sm', isDark ? 'text-amber-300' : 'text-amber-800')}>
                Erfordern 4-Augen-Freigabe
              </p>
            </div>
          </div>
        </Card>
        <Card
          className={clsx(
            'p-4 border',
            isDark ? 'bg-slate-800/90 border-blue-500/50' : 'bg-sky-50 border-sky-200',
          )}
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">🔢</span>
            <div>
              <p className={clsx('font-semibold', isDark ? 'text-blue-200' : 'text-sky-900')}>
                {stats?.openRoundingDiffs ?? 0} offene Rundungsdifferenzen
              </p>
              <p className={clsx('text-sm', isDark ? 'text-blue-300' : 'text-sky-800')}>
                Müssen geprüft werden
              </p>
            </div>
          </div>
        </Card>
      </div>

      {/* Two Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <RoundingDiffsList
          isDark={isDark}
          title="Offene Rundungsdifferenzen"
          emptyMessage="Keine offenen Rundungsdifferenzen."
          differences={(roundingDiffs ?? []).filter((d) => d.status === 'open')}
        />
        <CorrectionsList
          isDark={isDark}
          title="Offene Korrekturbuchungen"
          emptyMessage="Keine ausstehenden Korrekturbuchungen."
          corrections={(corrections ?? []).filter((c) => c.status === 'pending')}
        />
        <RoundingDiffsList
          isDark={isDark}
          title="Rundungsdifferenzen"
          differences={roundingDiffs ?? []}
        />
        <CorrectionsList isDark={isDark} title="Korrekturbuchungen" corrections={corrections ?? []} />
      </div>

      {/* Correction Modal */}
      {showCorrectionModal && <CorrectionModal onClose={() => setShowCorrectionModal(false)} />}
    </div>
  );
}

function RoundingDiffsList(props: {
  isDark: boolean;
  title: string;
  differences: RoundingDifference[];
  emptyMessage?: string;
}): JSX.Element {
  const { isDark, title, differences, emptyMessage } = props;
  const borderB = clsx('border-b', adminBorderChromeSoft(isDark));
  const borderT = clsx('border-t', adminBorderChromeSoft(isDark));
  const divideY = tableBodyDivideClasses(isDark);

  return (
    <Card>
      <div className={clsx('p-4', borderB)}>
        <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>{title}</h2>
      </div>
      <div className={divideY}>
        {differences.length === 0 ? (
          <div className={emptyListPlaceholderClasses(isDark)}>{emptyMessage ?? 'Keine Einträge.'}</div>
        ) : (
          differences.map((diff, index) => (
            <div
              key={diff.objectId}
              className={clsx('p-4 flex items-center justify-between', listRowStripeClasses(isDark, index))}
            >
              <div>
                <p className={clsx('font-medium', adminPrimary(isDark))}>{diff.transactionId}</p>
                <p className={clsx('text-sm', adminMuted(isDark))}>
                  {formatDateTime(diff.createdAt)}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <span
                  className={clsx(
                    'font-mono',
                    diff.amount >= 0
                      ? isDark
                        ? 'text-emerald-400'
                        : 'text-green-600'
                      : isDark
                        ? 'text-red-400'
                        : 'text-red-600',
                  )}
                >
                  {diff.amount >= 0 ? '+' : ''}
                  {diff.amount.toFixed(2)} {diff.currency}
                </span>
                <Badge variant={getStatusVariant(diff.status)}>
                  {diff.status === 'open' ? 'Offen' : diff.status === 'reviewed' ? 'Geprüft' : 'Erledigt'}
                </Badge>
              </div>
            </div>
          ))
        )}
      </div>
      <div className={clsx('p-4', borderT)}>
        <Button variant="ghost" className="w-full">
          Alle anzeigen →
        </Button>
      </div>
    </Card>
  );
}

function CorrectionsList(props: {
  isDark: boolean;
  title: string;
  corrections: CorrectionRequest[];
  emptyMessage?: string;
}): JSX.Element {
  const { isDark, title, corrections, emptyMessage } = props;

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

  const borderB = clsx('border-b', adminBorderChromeSoft(isDark));
  const borderT = clsx('border-t', adminBorderChromeSoft(isDark));
  const divideY = tableBodyDivideClasses(isDark);

  return (
    <Card>
      <div className={clsx('p-4', borderB)}>
        <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>{title}</h2>
      </div>
      <div className={divideY}>
        {corrections.length === 0 ? (
          <div className={emptyListPlaceholderClasses(isDark)}>{emptyMessage ?? 'Keine Einträge.'}</div>
        ) : (
          corrections.map((corr, index) => (
            <div key={corr.objectId} className={clsx('p-4', listRowStripeClasses(isDark, index))}>
              <div className="flex items-center justify-between mb-2">
                <span className={clsx('font-medium', adminPrimary(isDark))}>
                  {getTypeLabel(corr.type)}
                </span>
                <Badge variant={getStatusBadge(corr.status)}>{getStatusLabel(corr.status)}</Badge>
              </div>
              <p className={clsx('text-sm mb-1', adminSoft(isDark))}>{corr.reason}</p>
              <div className={clsx('flex items-center justify-between text-sm')}>
                <span className={clsx(adminMuted(isDark))}>{formatDateTime(corr.createdAt)}</span>
                <span className="font-semibold text-fin1-primary">{formatCurrency(corr.amount)}</span>
              </div>
            </div>
          ))
        )}
      </div>
      <div className={clsx('p-4', borderT)}>
        <Button variant="ghost" className="w-full">
          Alle anzeigen →
        </Button>
      </div>
    </Card>
  );
}
