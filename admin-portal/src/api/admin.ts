import { cloudFunction } from './parse';

// Re-export cloudFunction for direct use
export { cloudFunction };

// ============================================================================
// Types
// ============================================================================

export interface AdminUser {
  objectId: string;
  email: string;
  username: string;
  customerId: string;
  role: string;
  status: string;
  kycStatus: string;
  firstName?: string;
  lastName?: string;
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
  totalInvested: number;
  totalProfit: number;
  currentValue: number;
}

export interface InvestmentItem {
  objectId: string;
  traderId: string;
  amount: number;
  status: string;
  profit: number;
  createdAt: string;
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
  recentActivity: ActivityItem[];
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
  userId: string;
  assignedTo?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ComplianceEvent {
  objectId: string;
  eventType: string;
  severity: string;
  userId?: string;
  description: string;
  reviewed: boolean;
  reviewedBy?: string;
  createdAt: string;
}

export interface AuditLog {
  objectId: string;
  logType: string;
  action: string;
  userId: string;
  resourceType?: string;
  resourceId?: string;
  metadata?: Record<string, unknown>;
  createdAt: string;
}

export interface Permissions {
  role: string;
  permissions: string[];
  isFullAdmin: boolean;
  isElevated: boolean;
  roleDescription: string;
}

// ============================================================================
// API Functions
// ============================================================================

/**
 * Get admin dashboard statistics
 */
export async function getAdminDashboard(): Promise<DashboardStats> {
  return cloudFunction<DashboardStats>('getAdminDashboard');
}

/**
 * Get current user's permissions
 */
export async function getMyPermissions(): Promise<Permissions> {
  return cloudFunction<Permissions>('getMyPermissions');
}

/**
 * Search users
 */
export async function searchUsers(params: {
  query?: string;
  status?: string;
  role?: string;
  limit?: number;
  skip?: number;
}): Promise<{ users: AdminUser[]; total: number }> {
  return cloudFunction('searchUsers', params);
}

/**
 * Get user details with wallet, trades, investments
 */
export async function getUserDetails(userId: string): Promise<UserDetailsResponse> {
  const result = await cloudFunction<UserDetailsResponse>('getUserDetails', { userId });
  // Ensure objectId is set
  if (result.user) {
    result.user.objectId = result.user.objectId || (result.user as unknown as { id: string }).id;
  }
  return result;
}

/**
 * Update user status
 */
export async function updateUserStatus(
  userId: string,
  status: string,
  reason: string
): Promise<{ success: boolean }> {
  return cloudFunction('updateUserStatus', { userId, status, reason });
}

/**
 * Get tickets
 */
export async function getTickets(params: {
  status?: string;
  priority?: string;
  assignedTo?: string;
  limit?: number;
  skip?: number;
}): Promise<{ tickets: Ticket[]; total: number }> {
  return cloudFunction('getTickets', params);
}

/**
 * Get compliance events
 */
export async function getComplianceEvents(params: {
  eventType?: string;
  severity?: string;
  reviewed?: boolean;
  limit?: number;
  skip?: number;
}): Promise<{ events: ComplianceEvent[]; total: number }> {
  return cloudFunction('getComplianceEvents', params);
}

/**
 * Review compliance event
 */
export async function reviewComplianceEvent(
  eventId: string,
  notes: string
): Promise<{ success: boolean }> {
  return cloudFunction('reviewComplianceEvent', { eventId, notes });
}

/**
 * Get audit logs
 */
export async function getAuditLogs(params: {
  logType?: string;
  action?: string;
  userId?: string;
  resourceType?: string;
  limit?: number;
  skip?: number;
}): Promise<{ logs: AuditLog[]; total: number }> {
  return cloudFunction('getAuditLogs', params);
}

/**
 * Get pending 4-eyes approvals
 */
export async function getPendingApprovals(): Promise<{ requests: unknown[] }> {
  return cloudFunction('getPendingApprovals');
}

/**
 * Approve 4-eyes request
 */
export async function approveRequest(
  requestId: string,
  notes?: string
): Promise<{ success: boolean }> {
  return cloudFunction('approveRequest', { requestId, notes });
}

/**
 * Reject 4-eyes request
 */
export async function rejectRequest(
  requestId: string,
  reason: string
): Promise<{ success: boolean }> {
  return cloudFunction('rejectRequest', { requestId, reason });
}

/**
 * Force password reset for user
 */
export async function forcePasswordReset(
  userId: string,
  reason: string
): Promise<{ success: boolean; message: string }> {
  return cloudFunction('forcePasswordReset', { userId, reason });
}

// ============================================================================
// Configuration Management
// ============================================================================

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

/**
 * Get system configuration
 */
export async function getConfiguration(): Promise<ConfigurationResponse> {
  return cloudFunction('getConfiguration');
}

/**
 * Get pending configuration changes
 */
export async function getPendingConfigurationChanges(): Promise<{ requests: PendingConfigChange[]; total: number }> {
  return cloudFunction('getPendingConfigurationChanges');
}

/**
 * Request a configuration change (may require 4-eyes approval)
 */
export async function requestConfigurationChange(params: {
  parameterName: string;
  newValue: number;
  reason: string;
}): Promise<{ success: boolean; requiresApproval: boolean; fourEyesRequestId?: string; message: string }> {
  return cloudFunction('requestConfigurationChange', params);
}

/**
 * Approve a configuration change
 */
export async function approveConfigurationChange(
  requestId: string,
  notes?: string
): Promise<{ success: boolean }> {
  return cloudFunction('approveConfigurationChange', { requestId, notes });
}

/**
 * Reject a configuration change
 */
export async function rejectConfigurationChange(
  requestId: string,
  reason: string
): Promise<{ success: boolean }> {
  return cloudFunction('rejectConfigurationChange', { requestId, reason });
}

// ============================================================================
// System Health
// ============================================================================

export interface SystemHealth {
  overall: 'healthy' | 'degraded' | 'down';
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

/**
 * Get system health status
 */
export async function getSystemHealth(): Promise<SystemHealth> {
  return cloudFunction('getSystemHealth');
}
