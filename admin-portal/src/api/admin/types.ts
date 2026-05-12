// ============================================================================
// Admin API — shared types (Parse Cloud responses)
// ============================================================================

export interface AdminUser {
  objectId: string;
  email: string;
  username: string;
  /** Business customer number (ANL-/TRD-…), canonical on _User.customerNumber */
  customerNumber: string;
  role: string;
  status: string;
  kycStatus: string;
  accountType?: string;
  companyKybStatus?: string;
  firstName?: string;
  lastName?: string;
  salutation?: string;
  phoneNumber?: string;
  streetAndNumber?: string;
  postalCode?: string;
  city?: string;
  state?: string;
  country?: string;
  dateOfBirth?: string;
  nationality?: string;
  createdAt: string;
  updatedAt: string;
  lastLoginAt?: string;
}

export interface UserWallet {
  balance: number;
  currency: string;
  lastUpdated?: string;
}

export interface TradeSummary {
  totalTrades: number;
  completedTrades: number;
  activeTrades: number;
  totalProfit: number;
  totalCommission: number;
}

export interface TradeInvestor {
  investmentId: string;
  investorEmail: string;
  investorName: string;
  ownershipPercentage: number;
  investedAmount: number;
  profitShare: number;
  commissionAmount: number;
  isSettled: boolean;
}

export interface TradeItem {
  objectId: string;
  tradeNumber: number;
  symbol: string;
  description?: string;
  status: string;
  grossProfit: number;
  netProfit?: number;
  totalFees?: number;
  createdAt: string;
  completedAt?: string;
  investors?: TradeInvestor[];
}

export interface InvestmentSummary {
  totalInvestments: number;
  activeInvestments: number;
  completedInvestments?: number;
  reservedInvestments?: number;
  totalInvested: number;
  totalProfit: number;
  currentValue: number;
}

export interface InvestmentItem {
  objectId: string;
  traderId: string;
  traderName?: string;
  amount: number;
  status: string;
  profit: number;
  currentValue?: number;
  investmentNumber?: string;
  serviceChargeAmount?: number;
  totalCommissionPaid?: number;
  numberOfTrades?: number;
  profitPercentage?: number;
  createdAt: string;
  activatedAt?: string;
  completedAt?: string;
  tradeNumber?: number | null;
  tradeSymbol?: string | null;
  tradeStatus?: string | null;
  tradeCompletedAt?: string | null;
  ownershipPercentage?: number;
  allocatedAmount?: number;
  docRef?: string | null;
}

export interface AccountStatementEntryItem {
  objectId: string;
  entryType: string;
  amount: number;
  balanceAfter: number;
  tradeId?: string;
  tradeNumber?: number;
  investmentId?: string;
  description: string;
  referenceDocumentId?: string | null;
  source?: string;
  createdAt: string;
}

export interface AccountStatementData {
  initialBalance: number;
  closingBalance: number;
  totalCredits: number;
  totalDebits: number;
  netChange: number;
  entries: AccountStatementEntryItem[];
}

export interface ActivityItem {
  action: string;
  description: string;
  createdAt: string;
}

export interface UserDetailsResponse {
  user: AdminUser;
  profile: unknown;
  address: unknown;
  wallet: UserWallet | null;
  tradeSummary: TradeSummary | null;
  trades: TradeItem[];
  investmentSummary: InvestmentSummary | null;
  investments: InvestmentItem[];
  accountStatement?: AccountStatementData | null;
  recentActivity: ActivityItem[];
  walletControls?: {
    globalMode: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal';
    roleMode?: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal';
    accountTypeMode?: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal';
    userOverrideMode: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal' | null;
    effectiveMode: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal';
  };
}

export interface DashboardStats {
  users: {
    total: number;
    active: number;
    pending: number;
    suspended: number;
  };
  tickets?: {
    open: number;
    pending: number;
    resolved: number;
  };
  compliance?: {
    pendingReviews: number;
    pendingApprovals: number;
  };
}

export interface Ticket {
  objectId: string;
  ticketNumber: string;
  subject: string;
  status: string;
  priority: string;
  category: string;
  userId: string;
  userEmail?: string;
  assignedTo?: string;
  assignedToName?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ComplianceEvent {
  objectId: string;
  eventType: string;
  severity: string;
  userId?: string;
  userEmail?: string;
  description: string;
  reviewed: boolean;
  reviewedBy?: string;
  reviewedAt?: string;
  reviewNotes?: string;
  metadata?: Record<string, unknown>;
  createdAt: string;
  occurredAt?: string;
}

export interface AuditLog {
  objectId: string;
  logType: string;
  action: string;
  userId: string;
  userEmail?: string;
  userRole?: string;
  resourceType?: string;
  resourceId?: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  createdAt: string;
}

export interface Permissions {
  role: string;
  permissions: string[];
  isFullAdmin: boolean;
  isElevated: boolean;
  roleDescription: string;
}

export interface ConfigurationResponse {
  config: Record<string, number | string | boolean>;
  pendingChanges?: PendingConfigChange[];
}

export interface PendingConfigChange {
  id: string;
  parameterName: string;
  oldValue: number | string | boolean;
  newValue: number | string | boolean;
  reason: string;
  requesterId: string;
  requesterEmail: string;
  requesterRole: string;
  createdAt: string;
  expiresAt: string;
}

export interface SystemHealth {
  overall: 'healthy' | 'degraded' | 'down' | 'unknown';
  services: Array<{
    name: string;
    status: 'healthy' | 'degraded' | 'down' | 'unknown';
    responseTime?: number;
    lastCheck: string;
  }>;
  databases: Array<{
    name: string;
    connected: boolean;
    version?: string;
    collections?: number;
  }>;
  serverTime: string;
  uptime: number;
  version: string;
}

export interface DevResetTradingTestDataResult {
  dryRun: boolean;
  nodeEnv: string;
  counts: Record<string, number>;
  willDeleteTotal?: number;
  deleted?: Record<string, number>;
  deletedTotal?: number;
  completedAt?: string;
  note?: string;
  reseedInitialBalance?: boolean;
  configInitialAccountBalance?: number;
  wouldSeedWalletDeposits?: number;
  walletReseed?: {
    amountPerUser?: number;
    seededUsers?: number;
    eligibleUsers?: number;
    note?: string;
    skipped?: boolean;
    reason?: string;
    error?: string;
    errors?: Array<{ userId: string; message: string }>;
  };
}

export interface CleanupDuplicateInvestmentSplitsResult {
  success: boolean;
  dryRun: boolean;
  nodeEnv: string;
  scanLimit: number;
  scannedRows: number;
  duplicateGroupCount: number;
  keepCount: number;
  removableCount: number;
  reviewOnlyCount: number;
  deletedCount: number;
  hint?: string;
  sample?: Array<{
    key: string;
    keep: {
      id: string;
      status: string;
      updatedAt?: string;
    };
    removableIds: string[];
    reviewOnlyIds: string[];
  }>;
}

export interface KybSubmission {
  userId: string;
  customerNumber: string;
  email: string;
  firstName?: string;
  lastName?: string;
  companyKybStatus: string;
  companyKybStep?: string;
  companyKybCompletedAt?: string;
  createdAt: string;
}

export interface KybAuditEntry {
  objectId: string;
  step: string;
  completedAt: string;
  schemaVersion: number;
  answers: Record<string, unknown> | null;
  fullData: Record<string, unknown> | null;
}

export interface KybSubmissionDetailUser {
  objectId: string;
  customerNumber: string;
  email: string;
  firstName?: string;
  lastName?: string;
  accountType: string;
  companyKybStatus: string;
  companyKybStep?: string;
  companyKybCompleted: boolean;
  companyKybCompletedAt?: string;
  companyKybReviewedAt?: string;
  companyKybReviewedBy?: string;
  companyKybReviewNotes?: string;
}

export interface KybSubmissionDetail {
  user: KybSubmissionDetailUser;
  auditTrail: KybAuditEntry[];
  mergedData: Record<string, unknown> | null;
}
