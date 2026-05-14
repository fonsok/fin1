import { useQuery } from '@tanstack/react-query';
import { cleanupDuplicateInvestmentSplits, cloudFunction, devResetTradingTestData } from '../../api/admin';
import { Card, Button, Badge } from '../../components/ui';
import { formatDateTime } from '../../utils/format';
import type { SystemHealth, ServiceStatus } from './types';
import clsx from 'clsx';
import { useTheme } from '../../context/ThemeContext';
import { useState } from 'react';
import {
  SettlementConsistencyCard,
  type SettlementConsistencyStatus,
} from './components/SettlementConsistencyCard';
import {
  FinanceConsistencySmokeCard,
  type FinanceConsistencySmokeStatus,
} from './components/FinanceConsistencySmokeCard';
import { DevMaintenanceCard } from './components/DevMaintenanceCard';
import { SystemServicesCard } from './components/SystemServicesCard';
import { SystemDatabasesCard } from './components/SystemDatabasesCard';

import { adminMuted, adminPrimary, adminSoft } from '../../utils/adminThemeClasses';
function StatusBadge({ status }: { status: ServiceStatus['status'] }) {
  const variants: Record<ServiceStatus['status'], 'success' | 'warning' | 'danger' | 'neutral'> = {
    healthy: 'success',
    degraded: 'warning',
    down: 'danger',
    unknown: 'neutral',
  };

  const labels: Record<ServiceStatus['status'], string> = {
    healthy: 'Gesund',
    degraded: 'Beeinträchtigt',
    down: 'Ausgefallen',
    unknown: 'Unbekannt',
  };

  return <Badge variant={variants[status]}>{labels[status]}</Badge>;
}

function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);

  return parts.join(' ') || '< 1m';
}

export function SystemHealthPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [resetBusy, setResetBusy] = useState(false);
  const [cleanupBusy, setCleanupBusy] = useState(false);
  const [resetScope, setResetScope] = useState<'all' | 'sinceHours' | 'testUsers'>('all');
  const [resetSinceHours, setResetSinceHours] = useState<number>(24);
  const [reseedInitialBalance, setReseedInitialBalance] = useState(false);
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['systemHealth'],
    queryFn: () => cloudFunction<SystemHealth>('getSystemHealth'),
    refetchInterval: 30000,
    // Nach Ubuntu-Neustart sind Parse/Docker oft kurz nicht erreichbar — mehrere Versuche
    // vermeiden fälschlich „Status unbekannt“, solange der Dienst nur verzögert hochkommt.
    retry: 5,
    retryDelay: (failureCount) => Math.min(1000 * 2 ** failureCount, 8000),
  });
  const {
    data: settlementConsistencyData,
    isLoading: settlementConsistencyLoading,
    isError: settlementConsistencyError,
  } = useQuery({
    queryKey: ['tradeSettlementConsistencyStatus'],
    queryFn: () => cloudFunction<SettlementConsistencyStatus>('getTradeSettlementConsistencyStatus', { limit: 100 }),
    refetchInterval: 30000,
  });
  const {
    data: financeSmokeData,
    isLoading: financeSmokeLoading,
    isError: financeSmokeError,
  } = useQuery({
    queryKey: ['financeConsistencySmoke'],
    queryFn: () => cloudFunction<FinanceConsistencySmokeStatus>('runFinanceConsistencySmoke', {
      userFilter: 'eweber',
      ledgerSampleLimit: 500,
      sinceHours: 168,
      settlementLimit: 100,
    }),
    refetchInterval: 30000,
  });

  const fallback: SystemHealth = {
    // Do not equate transport/auth errors with a real outage ("Systemausfall").
    overall: isError && !data ? 'unknown' : 'healthy',
    services: [],
    databases: [],
    serverTime: new Date().toISOString(),
    uptime: 0,
    version: '-',
  };

  const health = data || fallback;
  const settlementConsistency: SettlementConsistencyStatus = settlementConsistencyData || {
    overall: settlementConsistencyError ? 'down' : 'unknown',
    checkedTrades: 0,
    checkedInvestments: 0,
    mismatchCount: 0,
    epsilon: 0.02,
    checkedAt: new Date().toISOString(),
    mismatchSamples: [],
  };
  const financeSmoke: FinanceConsistencySmokeStatus = financeSmokeData || {
    overall: financeSmokeError ? 'down' : 'unknown',
    checkedAt: new Date().toISOString(),
    issues: [],
    mirrorBasis: { overall: 'unknown' },
    settlementConsistency: { overall: 'unknown', checkedTrades: 0, checkedInvestments: 0, mismatchCount: 0 },
    ledgerFuzzySmoke: { fuzzyUserFilter: 'eweber', sampledRows: 0, matches: 0, parseObjectIdFilterWouldApply: false },
    referenceCoverage: { checkedRows: 0, missingReferenceDocumentId: 0 },
  };

  const overallStatusColor = {
    healthy: 'text-green-500',
    degraded: 'text-yellow-500',
    down: 'text-red-500',
    unknown: isDark ? 'text-slate-400' : 'text-slate-500',
  }[health.overall];

  const overallStatusBg = {
    healthy: isDark ? 'bg-emerald-950/30 border-emerald-700' : 'bg-green-50 border-green-200',
    degraded: isDark ? 'bg-amber-950/30 border-amber-700' : 'bg-yellow-50 border-yellow-200',
    down: isDark ? 'bg-red-950/30 border-red-700' : 'bg-red-50 border-red-200',
    unknown: isDark ? 'bg-slate-900/40 border-slate-600' : 'bg-slate-50 border-slate-200',
  }[health.overall];

  async function handleDevResetTradingTestData() {
    if (resetBusy) return;
    setResetBusy(true);
    try {
      const preview = await devResetTradingTestData({
        dryRun: true,
        scope: resetScope,
        sinceHours: resetScope === 'sinceHours' ? resetSinceHours : undefined,
        reseedInitialBalance,
      } as unknown as { dryRun: boolean });
      const lines = Object.entries(preview.counts || {})
        .filter(([, c]) => (c || 0) > 0)
        .map(([k, c]) => `- ${k}: ${c}`);

      const ok = window.confirm(
        [
          'DEV Reset (Preview)',
          '',
          `Umgebung: ${preview.nodeEnv}`,
          `Scope: ${resetScope}${resetScope === 'sinceHours' ? ` (${resetSinceHours}h)` : ''}`,
          `Objekte die gelöscht werden: ${preview.willDeleteTotal ?? '-'}`,
          '',
          ...lines,
          '',
          'Fortfahren? Dies löscht Testdaten aus Trading/Investments inkl. Belegen/Buchungen.',
          'Templates/Vorlagen bleiben erhalten.',
        ].join('\n')
      );

      if (!ok) return;

      const result = await devResetTradingTestData({
        dryRun: false,
        scope: resetScope,
        sinceHours: resetScope === 'sinceHours' ? resetSinceHours : undefined,
        reseedInitialBalance,
      } as unknown as { dryRun: boolean });
      window.alert(
        [
          'DEV Reset abgeschlossen.',
          '',
          `Gelöscht gesamt: ${result.deletedTotal ?? '-'}`,
          '',
          ...Object.entries(result.deleted || {}).map(([k, c]) => `- ${k}: ${c}`),
        ].join('\n')
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      window.alert(`DEV Reset fehlgeschlagen: ${message}`);
    } finally {
      setResetBusy(false);
    }
  }

  async function handleCleanupDuplicateInvestmentSplits() {
    if (cleanupBusy) return;
    setCleanupBusy(true);
    try {
      const preview = await cleanupDuplicateInvestmentSplits({ dryRun: true, scanLimit: 1000 });
      const sampleLines = (preview.sample || [])
        .slice(0, 8)
        .map((item) => `- ${item.key}: remove=${item.removableIds.length}, reviewOnly=${item.reviewOnlyIds.length}`);

      const ok = window.confirm(
        [
          'Duplicate Investment Splits (Preview)',
          '',
          `Umgebung: ${preview.nodeEnv}`,
          `Geprüfte Zeilen: ${preview.scannedRows}`,
          `Duplikat-Gruppen: ${preview.duplicateGroupCount}`,
          `Entfernbar (stale reserved): ${preview.removableCount}`,
          `Nur Review: ${preview.reviewOnlyCount}`,
          '',
          ...sampleLines,
          '',
          'Fortfahren mit Cleanup? Es werden nur stale reserved Duplikate gelöscht.',
        ].join('\n')
      );

      if (!ok) return;

      const result = await cleanupDuplicateInvestmentSplits({ dryRun: false, scanLimit: 1000 });
      window.alert(
        [
          'Duplicate-Cleanup abgeschlossen.',
          '',
          `Geprüfte Zeilen: ${result.scannedRows}`,
          `Duplikat-Gruppen: ${result.duplicateGroupCount}`,
          `Gelöscht: ${result.deletedCount}`,
          `Review-only verbleibend: ${result.reviewOnlyCount}`,
        ].join('\n')
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      window.alert(`Duplicate-Cleanup fehlgeschlagen: ${message}`);
    } finally {
      setCleanupBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>System-Status</h2>
            <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
              Übersicht aller Services und Datenbanken
            </p>
          </div>
          <Button variant="secondary" onClick={() => refetch()} disabled={isLoading}>
            {isLoading ? 'Prüfe...' : 'Aktualisieren'}
          </Button>
        </div>
      </Card>

      {/* Overall Status */}
      <Card className={clsx('border', overallStatusBg)}>
        <div className="flex items-center gap-4">
          <div className={clsx('w-16 h-16 rounded-full flex items-center justify-center', overallStatusColor)}>
            {health.overall === 'healthy' ? (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            ) : health.overall === 'degraded' ? (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            ) : health.overall === 'unknown' ? (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            ) : (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            )}
          </div>
          <div>
            <h3 className={clsx('text-xl font-semibold', adminPrimary(isDark))}>
              {health.overall === 'healthy' ? 'Alle Systeme betriebsbereit' :
               health.overall === 'degraded' ? 'Einige Systeme beeinträchtigt' :
               health.overall === 'unknown' ? 'Systemstatus konnte nicht geladen werden' :
               'Systemausfall erkannt'}
            </h3>
            <p className={clsx('text-sm mt-1', adminSoft(isDark))}>
              Letzte Prüfung: {formatDateTime(health.serverTime)}
            </p>
            {isError && !data && (
              <p className={clsx('text-sm mt-2', isDark ? 'text-amber-200/90' : 'text-amber-800')}>
                {error instanceof Error ? error.message : String(error)}
              </p>
            )}
          </div>
        </div>
      </Card>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <div className="text-center">
            <p className={clsx('text-sm', adminMuted(isDark))}>Uptime</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">{formatUptime(health.uptime)}</p>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <p className={clsx('text-sm', adminMuted(isDark))}>Version</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">v{health.version}</p>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <p className={clsx('text-sm', adminMuted(isDark))}>Services</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">
              {health.services.filter(s => s.status === 'healthy').length}/{health.services.length}
            </p>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <p className={clsx('text-sm', adminMuted(isDark))}>Node.js</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">{health.nodeVersion || '-'}</p>
          </div>
        </Card>
      </div>

      <SystemServicesCard
        isDark={isDark}
        services={health.services}
        renderStatusBadge={(status) => <StatusBadge status={status} />}
      />

      <SystemDatabasesCard
        isDark={isDark}
        databases={health.databases}
      />

      <SettlementConsistencyCard
        isDark={isDark}
        settlementConsistency={settlementConsistency}
        settlementConsistencyLoading={settlementConsistencyLoading}
        renderStatusBadge={(status) => <StatusBadge status={status} />}
      />

      <FinanceConsistencySmokeCard
        isDark={isDark}
        financeSmoke={financeSmoke}
        financeSmokeLoading={financeSmokeLoading}
        renderStatusBadge={(status) => <StatusBadge status={status} />}
      />

      <DevMaintenanceCard
        isDark={isDark}
        resetBusy={resetBusy}
        cleanupBusy={cleanupBusy}
        resetScope={resetScope}
        resetSinceHours={resetSinceHours}
        reseedInitialBalance={reseedInitialBalance}
        onResetScopeChange={setResetScope}
        onResetSinceHoursChange={setResetSinceHours}
        onReseedInitialBalanceChange={setReseedInitialBalance}
        onResetTradingData={handleDevResetTradingTestData}
        onCleanupDuplicateSplits={handleCleanupDuplicateInvestmentSplits}
      />

      {/* Info */}
      <Card
        className={clsx(
          'border',
          isDark ? 'bg-slate-800/90 border-slate-600' : 'bg-slate-100 border-slate-200',
        )}
      >
        <div className="flex gap-3">
          <svg
            className={clsx('w-5 h-5 flex-shrink-0 mt-0.5', isDark ? 'text-slate-400' : 'text-slate-500')}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div className={clsx('text-sm', isDark ? 'text-slate-200' : 'text-slate-700')}>
            <p>Die Statusabfrage erfolgt automatisch alle 30 Sekunden.</p>
            <p className="mt-1">Server-Zeit: {formatDateTime(health.serverTime)}</p>
          </div>
        </div>
      </Card>
    </div>
  );
}
