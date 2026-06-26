import clsx from 'clsx';
import type { ReactNode } from 'react';
import { Badge, Card } from '../../../components/ui';
import { formatDateTime } from '../../../utils/format';

import { adminLabel, adminMonoHint, adminMuted, adminPrimary, adminSurfaceMetricTile } from '../../../utils/adminThemeClasses';
import {
  classifyFinanceSmokeIssues,
  FINANCE_SNAPSHOT_CATCHUP_COMMAND,
  formatSnapshotCheckMetrics,
  snapshotCheckLabel,
} from '../utils/financeConsistencySmokeIssues';

type HealthStatus = 'healthy' | 'degraded' | 'down' | 'unknown';

export type FinanceConsistencySmokeStatus = {
  overall: HealthStatus;
  checkedAt: string;
  issues: string[];
  financeIntegrity?: {
    overall?: HealthStatus;
    issues?: string[];
    checks?: Array<{
      id: string;
      label?: string;
      overall?: HealthStatus;
      reason?: string | null;
      runAt?: string | null;
      ageSeconds?: number | null;
      hasSnapshot?: boolean;
      driftedDocuments?: number;
      checkedDocuments?: number;
      violationCount?: number;
    }>;
  };
  mirrorBasis?: {
    overall?: HealthStatus;
    hasSnapshot?: boolean;
    reason?: string | null;
    runAt?: string | null;
    ageSeconds?: number | null;
    checkedDocuments?: number;
    driftedDocuments?: number;
    nullDerivedCount?: number;
    violationCount?: number;
    driftSamples?: Array<{
      docId?: string;
      investmentId?: string;
      tradeId?: string;
      storedReturnPercentage?: number;
      derivedReturnPercentage?: number;
      deltaPp?: number;
    }>;
  };
  traderCashDuplicates?: {
    overall?: HealthStatus;
    hasSnapshot?: boolean;
    reason?: string | null;
    runAt?: string | null;
    ageSeconds?: number | null;
    violationCount?: number;
    violationSamples?: Array<Record<string, unknown>>;
  };
  settlementConsistency?: { overall?: HealthStatus; checkedTrades?: number; checkedInvestments?: number; mismatchCount?: number };
  traderBelegDrift?: {
    overall?: HealthStatus;
    checkedDocuments?: number;
    driftedDocuments?: number;
    needsBackfillDocuments?: number;
    reason?: string | null;
    driftSamples?: Array<{
      objectId?: string;
      accountingDocumentNumber?: string;
      status?: string;
      drifts?: Array<{ field?: string; code?: string; snapshot?: number; metadata?: number }>;
    }>;
  };
  ledgerFuzzySmoke?: { fuzzyUserFilter?: string; sampledRows?: number; matches?: number; parseObjectIdFilterWouldApply?: boolean };
  referenceCoverage?: { checkedRows?: number; missingReferenceDocumentId?: number };
};

type Props = {
  isDark: boolean;
  financeSmoke: FinanceConsistencySmokeStatus;
  financeSmokeLoading: boolean;
  renderStatusBadge: (status: HealthStatus) => ReactNode;
};

function issueBorderClass(isDark: boolean, variant: 'maintenance' | 'data' | 'healthy') {
  if (variant === 'healthy') {
    return isDark ? 'border-emerald-700 bg-emerald-950/20' : 'border-green-200 bg-green-50';
  }
  if (variant === 'maintenance') {
    return isDark ? 'border-sky-700 bg-sky-950/20' : 'border-sky-200 bg-sky-50';
  }
  return isDark ? 'border-amber-700 bg-amber-950/20' : 'border-yellow-200 bg-yellow-50';
}

export function FinanceConsistencySmokeCard({
  isDark,
  financeSmoke,
  financeSmokeLoading,
  renderStatusBadge,
}: Props) {
  const classification = classifyFinanceSmokeIssues(financeSmoke);
  const cardVariant = financeSmoke.overall === 'healthy'
    ? 'healthy'
    : classification.staleOnly
      ? 'maintenance'
      : 'data';

  return (
    <Card className={clsx('border', issueBorderClass(isDark, cardVariant))}>
      <div className="flex items-start justify-between gap-4 flex-col md:flex-row">
        <div>
          <h3 className={clsx('text-md font-semibold', adminPrimary(isDark))}>
            Finance Consistency Smoke
          </h3>
          <p className={clsx('text-sm mt-1', adminLabel(isDark))}>
            Kompakter End-to-End Smoke fuer Ledger/Konten/Buchungen/User-Fuzzy/Belegkette.
          </p>
          <p className={clsx('text-xs mt-1', adminMonoHint(isDark))}>
            Letzte Pruefung: {formatDateTime(financeSmoke.checkedAt)}
          </p>
          {classification.staleOnly && (
            <p className={clsx('text-xs mt-2', isDark ? 'text-sky-300' : 'text-sky-700')}>
              Veraltete Wochen-Snapshots — Finanzdaten laut letzter Pruefung konsistent. Cron auf iobox nachholen.
            </p>
          )}
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          {financeSmokeLoading ? <Badge variant="neutral">Laedt…</Badge> : (
            <>
              {renderStatusBadge(financeSmoke.overall)}
              {classification.staleOnly && <Badge variant="info">Nur Wartung</Badge>}
            </>
          )}
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className={clsx('rounded-md border p-3', adminSurfaceMetricTile(isDark))}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Daten-Issues</p>
          <p
            className={clsx(
              'text-lg font-semibold',
              classification.dataIssues.length === 0
                ? isDark
                  ? 'text-emerald-400'
                  : 'text-green-500'
                : isDark
                  ? 'text-amber-400'
                  : 'text-yellow-500',
            )}
          >
            {classification.dataIssues.length}
          </p>
        </div>
        <div className={clsx('rounded-md border p-3', adminSurfaceMetricTile(isDark))}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Wartung (Snapshots)</p>
          <p
            className={clsx(
              'text-lg font-semibold',
              classification.maintenanceChecks.length === 0
                ? adminPrimary(isDark)
                : isDark
                  ? 'text-sky-300'
                  : 'text-sky-600',
            )}
          >
            {classification.maintenanceChecks.length}
          </p>
        </div>
        <div className={clsx('rounded-md border p-3', adminSurfaceMetricTile(isDark))}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Settlement Trades</p>
          <p className={clsx('text-lg font-semibold', adminPrimary(isDark))}>{financeSmoke.settlementConsistency?.checkedTrades ?? 0}</p>
        </div>
        <div className={clsx('rounded-md border p-3', adminSurfaceMetricTile(isDark))}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Ledger Fuzzy Matches</p>
          <p className={clsx('text-lg font-semibold', adminPrimary(isDark))}>{financeSmoke.ledgerFuzzySmoke?.matches ?? 0}</p>
        </div>
        <div className={clsx('rounded-md border p-3', adminSurfaceMetricTile(isDark))}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Trader Beleg Drift</p>
          <p
            className={clsx(
              'text-lg font-semibold',
              (financeSmoke.traderBelegDrift?.driftedDocuments || 0) === 0
                && (financeSmoke.traderBelegDrift?.needsBackfillDocuments || 0) === 0
                ? isDark
                  ? 'text-emerald-400'
                  : 'text-green-500'
                : isDark
                  ? 'text-amber-400'
                  : 'text-yellow-500',
            )}
          >
            {financeSmoke.traderBelegDrift?.driftedDocuments ?? 0}
          </p>
        </div>
        <div className={clsx('rounded-md border p-3', adminSurfaceMetricTile(isDark))}>
          <p className={clsx('text-xs', adminMuted(isDark))}>Missing Beleg-Refs</p>
          <p
            className={clsx(
              'text-lg font-semibold',
              (financeSmoke.referenceCoverage?.missingReferenceDocumentId || 0) === 0
                ? isDark
                  ? 'text-emerald-400'
                  : 'text-green-500'
                : isDark
                  ? 'text-red-400'
                  : 'text-red-500',
            )}
          >
            {financeSmoke.referenceCoverage?.missingReferenceDocumentId ?? 0}
          </p>
        </div>
      </div>

      {classification.hasMaintenance && (
        <div className={clsx(
          'mt-3 rounded-md border px-3 py-2 text-sm space-y-2',
          isDark ? 'border-sky-700 bg-sky-950/30 text-sky-100' : 'border-sky-300 bg-sky-50 text-sky-900',
        )}>
          <p className="font-medium">Wartung: veraltete OpsHealth-Snapshots (kein Datenproblem)</p>
          <ul className="text-xs space-y-2 list-disc pl-4">
            {classification.maintenanceChecks.map((check) => (
              <li key={check.id}>
                <span className="font-medium">{snapshotCheckLabel(check.id)}:</span>{' '}
                {check.reason}
                {check.runAt ? ` (Snapshot ${formatDateTime(check.runAt)})` : ''}
                {formatSnapshotCheckMetrics(check) ? ` — ${formatSnapshotCheckMetrics(check)}` : ''}
              </li>
            ))}
          </ul>
          <p className={clsx('text-xs font-mono break-all', adminMonoHint(isDark))}>
            Nachholen: {FINANCE_SNAPSHOT_CATCHUP_COMMAND}
          </p>
          <p className={clsx('text-xs', adminMuted(isDark))}>
            Regulaerer Cron: Montag 06:00 auf iobox (`run-finance-integrity-snapshots.sh`).
          </p>
        </div>
      )}

      {classification.hasDataIssues && (
        <div className={clsx('mt-3 rounded-md border px-3 py-2 text-sm space-y-2', isDark ? 'border-amber-700 bg-amber-950/30 text-amber-200' : 'border-yellow-300 bg-yellow-50 text-yellow-800')}>
          <p>
            <span className="font-medium">Daten-Inkonsistenzen:</span> {classification.dataIssues.join(', ')}
          </p>
          {financeSmoke.mirrorBasis?.reason && !classification.maintenanceChecks.some((c) => c.id === 'mirror_basis_drift') && (
            <p className={clsx('text-xs', adminMonoHint(isDark))}>
              Mirror-Basis: {financeSmoke.mirrorBasis.reason}
              {financeSmoke.mirrorBasis.runAt
                ? ` (Snapshot ${formatDateTime(financeSmoke.mirrorBasis.runAt)})`
                : ''}
              {typeof financeSmoke.mirrorBasis.driftedDocuments === 'number'
                ? ` — geprüft: ${financeSmoke.mirrorBasis.checkedDocuments ?? 0}, Drift: ${financeSmoke.mirrorBasis.driftedDocuments}`
                : ''}
            </p>
          )}
          {(financeSmoke.mirrorBasis?.driftSamples?.length || 0) > 0 && (
            <details>
              <summary className="cursor-pointer text-xs font-medium">Drift-Beispiele (max. 5)</summary>
              <ul className="mt-1 text-xs font-mono space-y-1 list-disc pl-4">
                {financeSmoke.mirrorBasis!.driftSamples!.slice(0, 5).map((s) => (
                  <li key={s.docId || `${s.tradeId}-${s.investmentId}`}>
                    doc {s.docId || '—'} · Δ {s.deltaPp ?? '?'} pp (gespeichert {s.storedReturnPercentage ?? '—'} % vs. SSOT{' '}
                    {s.derivedReturnPercentage ?? '—'} %)
                  </li>
                ))}
              </ul>
            </details>
          )}
          {(financeSmoke.traderBelegDrift?.driftSamples?.length || 0) > 0 && (
            <details>
              <summary className="cursor-pointer text-xs font-medium">Trader-Beleg Drift (max. 5)</summary>
              <ul className="mt-1 text-xs font-mono space-y-1 list-disc pl-4">
                {financeSmoke.traderBelegDrift!.driftSamples!.slice(0, 5).map((s) => (
                  <li key={s.objectId || s.accountingDocumentNumber}>
                    {s.accountingDocumentNumber || s.objectId} · {s.status}
                    {s.drifts?.length ? ` · ${s.drifts.map((d) => d.field).join(', ')}` : ''}
                  </li>
                ))}
              </ul>
            </details>
          )}
        </div>
      )}

      {(financeSmoke.issues?.length || 0) === 0 && financeSmoke.mirrorBasis?.hasSnapshot && (
        <p className={clsx('mt-3 text-xs', adminMonoHint(isDark))}>
          Mirror-Basis: {financeSmoke.mirrorBasis.overall ?? 'healthy'}
          {financeSmoke.mirrorBasis.runAt ? ` · Snapshot ${formatDateTime(financeSmoke.mirrorBasis.runAt)}` : ''}
          {typeof financeSmoke.mirrorBasis.checkedDocuments === 'number'
            ? ` · ${financeSmoke.mirrorBasis.checkedDocuments} Collection Bills geprüft`
            : ''}
        </p>
      )}
    </Card>
  );
}
