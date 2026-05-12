export interface AppLedgerEntry {
  id: string;
  account: string;
  chartCodeSnapshot?: string;
  chartVersionSnapshot?: string;
  externalAccountNumberSnapshot?: string;
  vatKeySnapshot?: string;
  taxTreatmentSnapshot?: string;
  mappingIdSnapshot?: string;
  side: 'credit' | 'debit';
  amount: number;
  userId: string;
  userRole: string;
  transactionType: string;
  referenceId: string;
  referenceType: string;
  description: string;
  createdAt: string;
  metadata: Record<string, string>;
}

export interface AccountTotals {
  credit: number;
  debit: number;
  net: number;
}

export interface AccountDef {
  code: string;
  name: string;
  group: string;
  chartCode?: string;
  chartVersion?: string;
  externalAccountNumber?: string;
  vatKey?: string;
  taxTreatment?: string;
}

export interface VATSummary {
  outputVATCollected: number;
  outputVATRemitted: number;
  inputVATClaimed: number;
  outstandingVATLiability: number;
}

export interface LedgerResponse {
  entries: AppLedgerEntry[];
  totals: Record<string, AccountTotals>;
  totalRevenue: number;
  totalRefunds: number;
  vatSummary: VATSummary;
  totalCount: number;
  accounts: AccountDef[];
  strictMappingEnabled?: boolean;
}

export interface LedgerMappingValidationReport {
  chartCode: string;
  chartVersion: string;
  strictMappingEnabled: boolean;
  totalInternalAccounts: number;
  totalMappings: number;
  missingMappings: string[];
  duplicateMappingIds: string[];
  isValid: boolean;
}

export type DateRangePreset = 'all' | 'thisMonth' | 'lastMonth' | 'thisYear' | 'last30Days' | 'custom';
