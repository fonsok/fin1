// ============================================================================
// Parse Cloud Code
// utils/permissions.js - Role-Based Access Control
// ============================================================================
//
// Differenzierte Berechtigungen pro Rolle nach Separation of Duties.
// Dokumentation: Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md
//
// ============================================================================

'use strict';

/**
 * Permission definitions per role.
 *
 * Roles (ordered by privilege level):
 * - admin: Full app-level admin (but not Dashboard Root)
 * - business_admin: Accounting/financial oversight, reports, corrections
 * - security_officer: Security reviews, release approvals, audit access
 * - compliance: Audit logs, compliance events, 4-eyes approvals
 * - customer_service: User support, tickets, KYC status
 * - system: Automated processes only
 *
 * Note: Parse Dashboard access is SEPARATE from these roles and
 * should only be available to Server-Admin via SSH tunnel.
 *
 * Role Hierarchy (for future reference):
 * ┌─────────────────────────────────────────────────────────────┐
 * │  Server-Admin (Dashboard Root) - NOT in this system        │
 * ├─────────────────────────────────────────────────────────────┤
 * │  admin              - Full app-level admin                 │
 * │  business_admin     - Financial/Accounting oversight       │
 * │  security_officer   - Security & Release gatekeeper        │
 * │  compliance         - Audit & 4-eyes approvals             │
 * │  customer_service   - User support                         │
 * ├─────────────────────────────────────────────────────────────┤
 * │  investor / trader  - End users                            │
 * └─────────────────────────────────────────────────────────────┘
 */
const PERMISSIONS = {
  // ═══════════════════════════════════════════════════════════════
  // ADMIN - Full app-level permissions
  // ═══════════════════════════════════════════════════════════════
  admin: ['*'],

  // ═══════════════════════════════════════════════════════════════
  // BUSINESS ADMIN - Accounting/Financial oversight
  // For: CFO, Finance Manager, Accounting Lead
  // Focus: Financial reports, corrections, fee oversight
  // ═══════════════════════════════════════════════════════════════
  business_admin: [
    // Dashboard (financial focus)
    'getAdminDashboard',
    'getFinancialDashboard',

    // User management (read only)
    'searchUsers',
    'getUserDetails',
    'getUserFinancialSummary',

    // Financial reports
    'getReports',
    'exportReport',
    'getFinancialReports',
    'getRevenueReport',
    'getFeeReport',
    'getCommissionReport',
    'getRoundingDifferencesReport',

    // Accounting operations
    'getRoundingDifferences',
    'reviewRoundingDifference',
    'approveRoundingDifferenceResolution',
    'getBankReconciliation',
    'reviewBankReconciliation',

    // Correction bookings (with 4-eyes)
    'createCorrectionRequest',
    'getCorrectionRequests',
    'reviewCorrectionRequest',

    // Configuration management (with 4-eyes for critical params)
    'getConfiguration',
    'requestConfigurationChange',
    'approveConfigurationChange',
    'rejectConfigurationChange',
    'getPendingConfigurationChanges',
    'getConfigurationChangeHistory',

    // Investment/Trade overview (read only)
    'getInvestmentsSummary',
    'getTradesSummary',
    'getPortfolioOverview',

    // Compliance events (read for financial context)
    'getComplianceEvents',
    'getComplianceStatistics',

    // 4-eyes (can approve financial corrections)
    'getPendingApprovals',
    'approveRequest',
    'rejectRequest',

    // Audit logs (read)
    'getAuditLogs',
    'searchAuditLogs',

    // Invoices & Statements
    'getInvoices',
    'getStatements',
    'regenerateStatement',

    // Reports & Bank Contra Ledger
    'getSummaryReport',
    'getBankContraLedger',
  ],

  // ═══════════════════════════════════════════════════════════════
  // SECURITY OFFICER - Security & Release Gatekeeper
  // For: CISO, Security Lead, DevSecOps
  // Focus: Security reviews, release approvals, access monitoring
  // ═══════════════════════════════════════════════════════════════
  security_officer: [
    // Dashboard (security focus)
    'getAdminDashboard',
    'getSecurityDashboard',

    // User management (read + security actions)
    'searchUsers',
    'getUserDetails',
    'getUserSecurityProfile',
    'getLoginHistory',
    'getFailedLoginAttempts',
    'getUserSessions',
    'terminateUserSession',
    'forcePasswordReset',

    // Security events
    'getSecurityEvents',
    'getSecurityAlerts',
    'reviewSecurityAlert',
    'markSecurityAlertResolved',

    // Access monitoring
    'getDataAccessLogs',
    'getPermissionAudit',
    'getAdminActivityLog',

    // Compliance (security-relevant)
    'getComplianceEvents',
    'getComplianceStatistics',

    // Audit logs (full access)
    'getAuditLogs',
    'getAuditLogDetails',
    'searchAuditLogs',
    'exportAuditLogs',

    // Release & Deployment approvals
    'getPendingReleases',
    'approveRelease',
    'rejectRelease',
    'getReleaseHistory',

    // 4-eyes (can approve security-related)
    'getPendingApprovals',
    'approveRequest',
    'rejectRequest',

    // Configuration review (read only)
    'getSystemConfiguration',
    'getSecurityConfiguration',

    // Penetration test / vulnerability reports
    'getSecurityReports',
    'uploadSecurityReport',
  ],

  // ═══════════════════════════════════════════════════════════════
  // COMPLIANCE - Audit & Regulatory
  // For: Compliance Officer, Legal, Regulatory Affairs
  // Focus: MiFID II, AML, GDPR, audit trails
  // ═══════════════════════════════════════════════════════════════
  compliance: [
    // Dashboard (full view)
    'getAdminDashboard',

    // User management (read only)
    'searchUsers',
    'getUserDetails',

    // Compliance events
    'getComplianceEvents',
    'getComplianceEventDetails',
    'reviewComplianceEvent',
    'markComplianceEventReviewed',

    // 4-eyes approvals
    'getPendingApprovals',
    'approveRequest',
    'rejectRequest',
    'getApprovalHistory',

    // Configuration (read + approve, no direct changes)
    'getConfiguration',
    'approveConfigurationChange',
    'rejectConfigurationChange',
    'getPendingConfigurationChanges',
    'getConfigurationChangeHistory',

    // Audit logs (read)
    'getAuditLogs',
    'getAuditLogDetails',
    'searchAuditLogs',

    // Reports (read + export)
    'getReports',
    'exportReport',
    'getComplianceStatistics',

    // KYC reviews (for compliance verification)
    'viewKYCStatus',
    'getKYCDocuments',
    'reviewKYCDocument',

    // GDPR requests
    'getGDPRRequests',
    'processGDPRRequest',
    'exportUserData',

    // Legal document management
    'getLegalDocuments',
    'getLegalConsents',
    'getLegalDeliveryLogs',
  ],

  // ═══════════════════════════════════════════════════════════════
  // CUSTOMER SERVICE - User Support
  // For: Support Agents, CSR Team
  // Focus: Tickets, user assistance, basic account help
  // ═══════════════════════════════════════════════════════════════
  customer_service: [
    // Dashboard (limited)
    'getAdminDashboard',

    // User management (read + limited write)
    'searchUsers',
    'getUserDetails',
    'updateUserStatus_suspend',  // Can suspend
    'updateUserStatus_reactivate', // Can reactivate
    // Cannot: updateUserStatus_close, updateUserStatus_delete

    // Support tickets
    'getTickets',
    'getTicketDetails',
    'createTicket',
    'updateTicket',
    'assignTicket',
    'addTicketComment',
    'escalateTicket',

    // KYC (read only)
    'viewKYCStatus',
    'getKYCDocuments',
    // Cannot: approveKYC, rejectKYC

    // FAQ management
    'getFAQs',
    'getFAQCategories',

    // User communication
    'sendUserNotification',
    'getUserNotificationHistory',

    // Basic user account help
    'resetUserPassword',
    'unlockUserAccount',
    'resendVerificationEmail',

    // Template management (CSR role-based)
    'manageTemplates',
    'viewAnalytics',
  ],

  // ═══════════════════════════════════════════════════════════════
  // SYSTEM - Automated Processes
  // For: Cron jobs, webhooks, internal services
  // ═══════════════════════════════════════════════════════════════
  system: [
    'logComplianceEvent',
    'createAuditLog',
    'processScheduledJob',
    'sendSystemNotification',
    'updateSystemMetrics',
  ],
};

/**
 * Status changes allowed per role.
 * admin can do all, others are restricted.
 */
const STATUS_CHANGE_PERMISSIONS = {
  admin: ['pending', 'active', 'suspended', 'locked', 'closed', 'deleted'],
  business_admin: ['suspended', 'active'], // Can suspend/reactivate for financial reasons
  security_officer: ['suspended', 'locked', 'active'], // Can lock for security, suspend, reactivate
  compliance: [], // Cannot change status directly
  customer_service: ['suspended', 'active'], // Suspend and reactivate only
};

/**
 * Check if user has permission for an action.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 * @param {string} permission - The permission to check
 * @throws {Parse.Error} If user is not authenticated or lacks permission
 */
function requirePermission(request, permission) {
  if (!request.user) {
    throw new Parse.Error(
      Parse.Error.INVALID_SESSION_TOKEN,
      'Login required'
    );
  }

  const role = request.user.get('role');

  if (!role) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'User has no role assigned'
    );
  }

  const allowedPermissions = PERMISSIONS[role];

  if (!allowedPermissions) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Unknown role: ${role}`
    );
  }

  // Admin has all permissions
  if (allowedPermissions[0] === '*') {
    return true;
  }

  if (!allowedPermissions.includes(permission)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Permission '${permission}' not allowed for role '${role}'`
    );
  }

  return true;
}

/**
 * Check if user has ANY admin role (admin, customer_service, or compliance).
 * Use for basic admin area access, then check specific permissions.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 * @throws {Parse.Error} If user is not an admin-level role
 */
function requireAdminRole(request) {
  if (!request.user) {
    throw new Parse.Error(
      Parse.Error.INVALID_SESSION_TOKEN,
      'Login required'
    );
  }

  const role = request.user.get('role');
  const adminRoles = ['admin', 'business_admin', 'security_officer', 'compliance', 'customer_service'];

  if (!adminRoles.includes(role)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'Admin access required'
    );
  }

  return true;
}

/**
 * Check if user can change a user's status to the target status.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 * @param {string} targetStatus - The status to change to
 * @throws {Parse.Error} If user cannot change to this status
 */
function requireStatusChangePermission(request, targetStatus) {
  requireAdminRole(request);

  const role = request.user.get('role');
  const allowedStatuses = STATUS_CHANGE_PERMISSIONS[role] || [];

  if (role !== 'admin' && !allowedStatuses.includes(targetStatus)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Role '${role}' cannot change status to '${targetStatus}'`
    );
  }

  return true;
}

/**
 * Get list of permissions for a role.
 * Useful for UI to show/hide features.
 *
 * @param {string} role - The role to get permissions for
 * @returns {string[]} Array of permission strings
 */
function getPermissionsForRole(role) {
  return PERMISSIONS[role] || [];
}

/**
 * Check if a role exists and is valid.
 *
 * @param {string} role - The role to check
 * @returns {boolean} True if role is valid
 */
function isValidRole(role) {
  return Object.keys(PERMISSIONS).includes(role);
}

/**
 * Get all admin-level roles.
 *
 * @returns {string[]} Array of admin role names
 */
function getAdminRoles() {
  return [
    'admin',
    'business_admin',
    'security_officer',
    'compliance',
    'customer_service'
  ];
}

/**
 * Get roles that can approve 4-eyes requests.
 *
 * @returns {string[]} Array of role names with approval rights
 */
function getApprovalRoles() {
  return ['admin', 'business_admin', 'security_officer', 'compliance'];
}

/**
 * Get roles with financial/accounting access.
 *
 * @returns {string[]} Array of role names with financial access
 */
function getFinancialRoles() {
  return ['admin', 'business_admin'];
}

/**
 * Get roles with security/audit access.
 *
 * @returns {string[]} Array of role names with security access
 */
function getSecurityRoles() {
  return ['admin', 'security_officer', 'compliance'];
}

/**
 * Check if role has elevated privileges (above customer_service).
 *
 * @param {string} role - Role to check
 * @returns {boolean} True if role is elevated
 */
function isElevatedRole(role) {
  return ['admin', 'business_admin', 'security_officer', 'compliance'].includes(role);
}

/**
 * Log a permission check for audit trail.
 * Call this after successful permission checks for sensitive operations.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 * @param {string} permission - The permission that was checked
 * @param {string} resourceType - Type of resource accessed
 * @param {string} resourceId - ID of resource accessed
 */
async function logPermissionCheck(request, permission, resourceType, resourceId) {
  try {
    const AuditLog = Parse.Object.extend('AuditLog');
    const log = new AuditLog();

    log.set('logType', 'data_access');
    log.set('action', `permission_check:${permission}`);
    log.set('userId', request.user.id);
    log.set('userRole', request.user.get('role'));
    log.set('resourceType', resourceType);
    log.set('resourceId', resourceId);
    log.set('metadata', {
      permission,
      ip: request.ip,
      userAgent: request.headers?.['user-agent'],
    });

    await log.save(null, { useMasterKey: true });
  } catch (error) {
    // Don't fail the operation if audit logging fails
    console.error('Failed to log permission check:', error);
  }
}

module.exports = {
  PERMISSIONS,
  STATUS_CHANGE_PERMISSIONS,
  requirePermission,
  requireAdminRole,
  requireStatusChangePermission,
  getPermissionsForRole,
  isValidRole,
  getAdminRoles,
  getApprovalRoles,
  getFinancialRoles,
  getSecurityRoles,
  isElevatedRole,
  logPermissionCheck,
};
