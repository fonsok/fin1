import { useMemo } from 'react';
import { useAuth } from '../context/AuthContext';

/** Finance/Business-Admin: erweiterte Sidebar; diese Nav-IDs bleiben gesperrt. */
const BUSINESS_ADMIN_SIDEBAR_DISABLED_IDS = new Set([
  'system',
  'security',
  'onboarding',
  'compliance',
]);

function isFinanceBusinessAdminRole(role: string | undefined): boolean {
  return role === 'business_admin';
}

/** Sidebar / route gate: every entry is listed; `enabled` reflects Parse permissions. */
export interface NavItem {
  id: string;
  label: string;
  path: string;
  icon: string;
  enabled: boolean;
}

/**
 * Map current route to the nav item that owns it (longest path wins). Used for active tab, titles, and gates.
 */
export function matchNavItemForPath(pathname: string, items: NavItem[]): NavItem | undefined {
  const normalized =
    pathname.length > 1 && pathname.endsWith('/') ? pathname.slice(0, -1) : pathname;
  const path = normalized || '/';

  if (path === '/') {
    return items.find(i => i.id === 'dashboard');
  }

  const ordered = [...items]
    .filter(i => i.path !== '/')
    .sort((a, b) => b.path.length - a.path.length);

  for (const item of ordered) {
    if (path === item.path || path.startsWith(`${item.path}/`)) {
      return item;
    }
  }
  return undefined;
}

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

    // Templates
    canManageTemplates: hasPermission('manageTemplates') || user?.role === 'admin' || user?.role === 'customer_service',

    // FAQs - visible to all admins and customer service
    canManageFAQs: user?.role === 'admin' || user?.role === 'customer_service' || hasPermission('manageTemplates'),

    // Company KYB Review
    canReviewCompanyKyb: hasPermission('reviewCompanyKyb'),
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
export function useNavigation(): NavItem[] {
  const perms = usePermissions();
  const { user } = useAuth();

  const navItems = useMemo((): NavItem[] => {
    const financeAdminSidebarUnlocked = isFinanceBusinessAdminRole(user?.role);

    /** Sidebar-Klick + Route-Gate: Finance-Admin alle Punkte außer fest definierte Sperren. */
    const navEnabled = (itemId: string, allowedByPermission: boolean): boolean => {
      if (financeAdminSidebarUnlocked) {
        return !BUSINESS_ADMIN_SIDEBAR_DISABLED_IDS.has(itemId);
      }
      return allowedByPermission;
    };

    // Alle Einträge immer anzeigen (Transparenz); `enabled` steuert Klick & Seiteninhalt.
    return [
      {
        id: 'dashboard',
        label: 'Dashboard',
        path: '/',
        icon: 'home',
        enabled: navEnabled('dashboard', true),
      },
      {
        id: 'users',
        label: 'Benutzer',
        path: '/users',
        icon: 'users',
        enabled: navEnabled('users', perms.canViewUsers),
      },
      {
        id: 'tickets',
        label: 'Tickets',
        path: '/tickets',
        icon: 'ticket',
        enabled:
          user?.role === 'admin'
            ? false
            : navEnabled('tickets', perms.canViewTickets),
      },
      {
        id: 'onboarding',
        label: 'Onboarding',
        path: '/onboarding',
        icon: 'user-plus',
        enabled: navEnabled('onboarding', true),
      },
      {
        id: 'compliance',
        label: 'Compliance',
        path: '/compliance',
        icon: 'shield-check',
        enabled: navEnabled('compliance', perms.canViewCompliance),
      },
      {
        id: 'finance',
        label: 'Finanzen',
        path: '/finance',
        icon: 'currency-euro',
        enabled: navEnabled('finance', perms.canViewFinancials),
      },
      {
        id: 'security',
        label: 'Sicherheit',
        path: '/security',
        icon: 'lock-closed',
        enabled: navEnabled('security', perms.canViewSecurity),
      },
      {
        id: 'approvals',
        label: 'Freigaben',
        path: '/approvals',
        icon: 'check-circle',
        enabled: navEnabled('approvals', perms.canApprove4Eyes),
      },
      {
        id: 'kyb-review',
        label: 'KYB-Status',
        path: '/kyb-review',
        icon: 'building-office',
        enabled: navEnabled('kyb-review', perms.canReviewCompanyKyb),
      },
      {
        id: 'audit',
        label: 'Audit-Logs',
        path: '/audit',
        icon: 'document-text',
        enabled: navEnabled('audit', perms.canViewAuditLogs),
      },
      {
        id: 'templates',
        label: 'CSR Templates',
        path: '/templates',
        icon: 'document-text',
        enabled: navEnabled('templates', perms.canManageTemplates),
      },
      {
        id: 'faqs',
        label: 'Hilfe & Anleitung',
        path: '/faqs',
        icon: 'question-mark-circle',
        enabled: navEnabled('faqs', perms.canManageFAQs),
      },
      {
        id: 'terms',
        label: 'AGB & Rechtstexte',
        path: '/terms',
        icon: 'document-text',
        enabled: navEnabled('terms', perms.canManageFAQs),
      },
      {
        id: 'reports',
        label: 'Summary Report',
        path: '/reports',
        icon: 'chart-bar',
        enabled: navEnabled('reports', perms.canViewFinancials),
      },
      {
        id: 'document-search',
        label: 'Beleg-Suche',
        path: '/documents',
        icon: 'magnifying-glass',
        enabled: navEnabled('document-search', perms.canViewFinancials),
      },
      {
        id: 'app-ledger',
        label: 'App Ledger',
        path: '/app-ledger',
        icon: 'banknotes',
        enabled: navEnabled('app-ledger', perms.canViewFinancials),
      },
      {
        id: 'configuration',
        label: 'Konfiguration',
        path: '/configuration',
        icon: 'adjustments',
        enabled: navEnabled('configuration', perms.canViewConfiguration),
      },
      {
        id: 'system',
        label: 'System-Status',
        path: '/system',
        icon: 'server',
        enabled: navEnabled('system', perms.canViewSystemHealth),
      },
      {
        id: 'settings',
        label: 'Einstellungen',
        path: '/settings',
        icon: 'cog',
        enabled: navEnabled('settings', true),
      },
    ];
  }, [perms, user?.role]);

  return navItems;
}
