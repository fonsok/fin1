import { describe, expect, it } from 'vitest';
import {
  classifyFinanceSmokeIssues,
  isSnapshotMaintenanceCheck,
  isStaleSnapshotReason,
} from './financeConsistencySmokeIssues';
import type { FinanceConsistencySmokeStatus } from '../components/FinanceConsistencySmokeCard';

describe('financeConsistencySmokeIssues', () => {
  it('detects stale snapshot reasons', () => {
    expect(isStaleSnapshotReason('snapshot is getting stale (9 days old)')).toBe(true);
    expect(isStaleSnapshotReason('snapshot is stale (15 days old)')).toBe(true);
    expect(isStaleSnapshotReason('3 investorCollectionBill document(s) drifted')).toBe(false);
  });

  it('treats stale snapshots with zero drift as maintenance only', () => {
    expect(isSnapshotMaintenanceCheck({
      id: 'mirror_basis_drift',
      overall: 'degraded',
      reason: 'snapshot is getting stale (9 days old)',
      driftedDocuments: 0,
    })).toBe(true);

    expect(isSnapshotMaintenanceCheck({
      id: 'mirror_basis_drift',
      overall: 'degraded',
      reason: '2 investorCollectionBill document(s) drifted from mirror-basis SSOT',
      driftedDocuments: 2,
    })).toBe(false);
  });

  it('classifies stale-only finance smoke issues', () => {
    const smoke: FinanceConsistencySmokeStatus = {
      overall: 'degraded',
      checkedAt: '2026-06-24T10:00:00.000Z',
      issues: ['mirror_basis_drift_degraded', 'trader_cash_duplicates_degraded'],
      financeIntegrity: {
        checks: [
          {
            id: 'mirror_basis_drift',
            overall: 'degraded',
            reason: 'snapshot is getting stale (9 days old)',
            driftedDocuments: 0,
            checkedDocuments: 0,
          },
          {
            id: 'trader_cash_duplicates',
            overall: 'degraded',
            reason: 'snapshot is getting stale (9 days old)',
            violationCount: 0,
          },
        ],
      },
    };

    const result = classifyFinanceSmokeIssues(smoke);
    expect(result.staleOnly).toBe(true);
    expect(result.dataIssues).toEqual([]);
    expect(result.maintenanceChecks).toHaveLength(2);
  });

  it('keeps real drift issues in dataIssues', () => {
    const smoke: FinanceConsistencySmokeStatus = {
      overall: 'degraded',
      checkedAt: '2026-06-24T10:00:00.000Z',
      issues: ['mirror_basis_drift_degraded', 'settlement_consistency_degraded'],
      financeIntegrity: {
        checks: [
          {
            id: 'mirror_basis_drift',
            overall: 'degraded',
            reason: '1 investorCollectionBill document(s) drifted from mirror-basis SSOT',
            driftedDocuments: 1,
          },
        ],
      },
    };

    const result = classifyFinanceSmokeIssues(smoke);
    expect(result.staleOnly).toBe(false);
    expect(result.dataIssues).toEqual(['mirror_basis_drift_degraded', 'settlement_consistency_degraded']);
  });
});
