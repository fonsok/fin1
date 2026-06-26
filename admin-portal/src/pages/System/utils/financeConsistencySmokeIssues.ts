import type { FinanceConsistencySmokeStatus } from '../components/FinanceConsistencySmokeCard';

export type HealthStatus = 'healthy' | 'degraded' | 'down' | 'unknown';

export type OpsHealthSnapshotCheck = {
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
};

export const FINANCE_SNAPSHOT_CATCHUP_COMMAND =
  'ssh io@iobox \'~/fin1-server/scripts/run-finance-integrity-snapshots.sh\'';

const SNAPSHOT_CHECK_IDS = new Set(['mirror_basis_drift', 'trader_cash_duplicates']);

export function isStaleSnapshotReason(reason?: string | null): boolean {
  if (!reason) return false;
  const lower = reason.toLowerCase();
  return lower.includes('getting stale') || lower.includes('is stale');
}

export function isSnapshotMaintenanceCheck(check: OpsHealthSnapshotCheck): boolean {
  if (!check.overall || check.overall === 'healthy') return false;
  if (!isStaleSnapshotReason(check.reason)) return false;
  const drift = Number(check.driftedDocuments ?? 0);
  const violations = Number(check.violationCount ?? 0);
  return drift === 0 && violations === 0;
}

export function getSnapshotChecksFromSmoke(smoke: FinanceConsistencySmokeStatus): OpsHealthSnapshotCheck[] {
  const fromIntegrity = (smoke.financeIntegrity?.checks ?? []).filter((check) => SNAPSHOT_CHECK_IDS.has(check.id));
  if (fromIntegrity.length > 0) return fromIntegrity;

  const fallback: OpsHealthSnapshotCheck[] = [];
  if (smoke.mirrorBasis) {
    fallback.push({
      id: 'mirror_basis_drift',
      label: 'Mirror-basis ROI drift',
      ...smoke.mirrorBasis,
    });
  }
  if (smoke.traderCashDuplicates) {
    fallback.push({
      id: 'trader_cash_duplicates',
      label: 'Trader cash duplicate bookings',
      ...smoke.traderCashDuplicates,
    });
  }
  return fallback;
}

export function classifyFinanceSmokeIssues(smoke: FinanceConsistencySmokeStatus) {
  const snapshotChecks = getSnapshotChecksFromSmoke(smoke);
  const maintenanceChecks = snapshotChecks.filter(isSnapshotMaintenanceCheck);
  const maintenanceIssueIds = new Set(maintenanceChecks.map((check) => `${check.id}_${check.overall}`));

  const dataIssues = (smoke.issues ?? []).filter((issue) => !maintenanceIssueIds.has(issue));
  const staleOnly = (smoke.issues?.length ?? 0) > 0 && dataIssues.length === 0 && maintenanceChecks.length > 0;

  return {
    maintenanceChecks,
    dataIssues,
    staleOnly,
    hasMaintenance: maintenanceChecks.length > 0,
    hasDataIssues: dataIssues.length > 0,
  };
}

export function snapshotCheckLabel(checkId: string): string {
  switch (checkId) {
    case 'mirror_basis_drift':
      return 'Mirror-Basis';
    case 'trader_cash_duplicates':
      return 'Trader-Cash-Duplikate';
    default:
      return checkId;
  }
}

export function formatSnapshotCheckMetrics(check: OpsHealthSnapshotCheck): string {
  if (check.id === 'mirror_basis_drift') {
    return `geprüft: ${check.checkedDocuments ?? 0}, Drift: ${check.driftedDocuments ?? 0}`;
  }
  if (check.id === 'trader_cash_duplicates') {
    return `Duplikat-Gruppen: ${check.violationCount ?? 0}`;
  }
  return '';
}
