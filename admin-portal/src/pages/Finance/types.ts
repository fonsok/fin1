export interface FinancialStats {
  totalRevenue: number;
  totalFees: number;
  totalInvestments: number;
  pendingCorrections: number;
  openRoundingDiffs: number;
  monthlyRevenue: number;
  monthlyFees: number;
}

export interface RoundingDifference {
  objectId: string;
  transactionId: string;
  amount: number;
  currency: string;
  createdAt: string;
  status: 'open' | 'reviewed' | 'resolved';
  reviewedBy?: string;
}

export interface CorrectionRequest {
  objectId: string;
  type: string;
  amount: number;
  currency: string;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  requestedBy: string;
  createdAt: string;
}
