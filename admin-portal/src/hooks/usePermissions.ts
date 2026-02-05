import { useMemo } from 'react';
import { useAuth } from '../context/AuthContext';

/**
 * Hook to check permissions for UI elements
 */
export function usePermissions() {
  const { permissions, hasPermission, user } = useAuth();

  const checks = useMemo(() => ({
    // Role checks
    isAdmin: user?.role === 'admin',
    isBusinessAdmin: user?.role === 'business_admin',
    isSecurityOfficer: user?.role === 'security_officer',
    isCompliance: user?.role === 'compliance',
    isCustomerService: user?.role === 'customer_service',
    isElevated: permissions?.isElevated ?? false,
    isFullAdmin: permissions?.isFullAdmin ?? false,

    // Feature access
    canViewUsers: hasPermission('searchUsers'),
    canEditUserStatus: hasPermission('updateUserStatus_suspend') || hasPermission('updateUserStatus_reactivate'),
    canViewTickets: hasPermission('getTickets'),
    canManageTickets: hasPermission('updateTicket'),
    canViewCompliance: hasPermission('getComplianceEvents'),
    canReviewCompliance: hasPermission('reviewComplianceEvent'),
    canViewAuditLogs: hasPermission('getAuditLogs'),
    canApprove4Eyes: hasPermission('approveRequest'),
    canViewFinancials: hasPermission('getFinancialDashboard'),
    canViewSecurity: hasPermission('getSecurityDashboard'),
    canTerminateSessions: hasPermission('terminateUserSession'),
    canResetPasswords: hasPermission('forcePasswordReset'),

    // New: Configuration & System
    canViewConfiguration: hasPermission('getConfiguration') || user?.role === 'admin',
    canEditConfiguration: hasPermission('requestConfigurationChange') || user?.role === 'admin',
    canViewSystemHealth: user?.role === 'admin' || user?.role === 'security_officer',
  }), [permissions, hasPermission, user?.role]);

  return {
    ...checks,
    hasPermission,
    role: user?.role,
    roleDescription: permissions?.roleDescription,
  };
}

/**
 * Navigation items based on role
 */
export function useNavigation() {
  const perms = usePermissions();

  const navItems = useMemo(() => {
    const items = [
      {
        id: 'dashboard',
        label: 'Dashboard',
        path: '/',
        icon: 'home',
        visible: true, // Always visible for admins
      },
      {
        id: 'users',
        label: 'Benutzer',
        path: '/users',
        icon: 'users',
        visible: perms.canViewUsers,
      },
      {
        id: 'tickets',
        label: 'Tickets',
        path: '/tickets',
        icon: 'ticket',
        visible: perms.canViewTickets,
      },
      {
        id: 'compliance',
        label: 'Compliance',
        path: '/compliance',
        icon: 'shield-check',
        visible: perms.canViewCompliance,
      },
      {
        id: 'finance',
        label: 'Finanzen',
        path: '/finance',
        icon: 'currency-euro',
        visible: perms.canViewFinancials,
      },
      {
        id: 'security',
        label: 'Sicherheit',
        path: '/security',
        icon: 'lock-closed',
        visible: perms.canViewSecurity,
      },
      {
        id: 'approvals',
        label: 'Freigaben',
        path: '/approvals',
        icon: 'check-circle',
        visible: perms.canApprove4Eyes,
      },
      {
        id: 'audit',
        label: 'Audit-Logs',
        path: '/audit',
        icon: 'document-text',
        visible: perms.canViewAuditLogs,
      },
      // Technische Administration
      {
        id: 'configuration',
        label: 'Konfiguration',
        path: '/configuration',
        icon: 'adjustments',
        visible: perms.canViewConfiguration,
      },
      {
        id: 'system',
        label: 'System-Status',
        path: '/system',
        icon: 'server',
        visible: perms.canViewSystemHealth,
      },
      {
        id: 'settings',
        label: 'Einstellungen',
        path: '/settings',
        icon: 'cog',
        visible: true, // Always visible for all admins
      },
    ];

    return items.filter(item => item.visible);
  }, [perms]);

  return navItems;
}
