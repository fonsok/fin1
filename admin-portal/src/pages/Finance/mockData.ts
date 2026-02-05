import type { FinancialStats, RoundingDifference, CorrectionRequest } from './types';

export const mockStats: FinancialStats = {
  totalRevenue: 1250000.0,
  totalFees: 45000.0,
  totalInvestments: 8500000.0,
  pendingCorrections: 3,
  openRoundingDiffs: 7,
  monthlyRevenue: 125000.0,
  monthlyFees: 4500.0,
};

export const mockRoundingDiffs: RoundingDifference[] = [
  {
    objectId: 'rd1',
    transactionId: 'TXN-2026-0001',
    amount: 0.01,
    currency: 'EUR',
    createdAt: '2026-02-01T10:30:00Z',
    status: 'open',
  },
  {
    objectId: 'rd2',
    transactionId: 'TXN-2026-0002',
    amount: -0.02,
    currency: 'EUR',
    createdAt: '2026-02-01T14:15:00Z',
    status: 'open',
  },
  {
    objectId: 'rd3',
    transactionId: 'TXN-2026-0003',
    amount: 0.01,
    currency: 'EUR',
    createdAt: '2026-01-31T09:45:00Z',
    status: 'reviewed',
    reviewedBy: 'admin@test.com',
  },
];

export const mockCorrections: CorrectionRequest[] = [
  {
    objectId: 'cor1',
    type: 'fee_refund',
    amount: 25.0,
    currency: 'EUR',
    reason: 'Doppelte Gebührenabrechnung',
    status: 'pending',
    requestedBy: 'business_admin@fin1.de',
    createdAt: '2026-02-02T08:00:00Z',
  },
  {
    objectId: 'cor2',
    type: 'investment_adjustment',
    amount: 100.0,
    currency: 'EUR',
    reason: 'Fehlerhafte Kursberechnung',
    status: 'approved',
    requestedBy: 'business_admin@fin1.de',
    createdAt: '2026-02-01T16:30:00Z',
  },
];
