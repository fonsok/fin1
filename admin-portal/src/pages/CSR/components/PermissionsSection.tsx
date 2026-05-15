import { useEffect, useMemo } from 'react';
import clsx from 'clsx';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { cloudFunction } from '../../../api/parse';
import type { User } from '../../../context/AuthContext';

import { adminBorderChromeSoft, adminCaption, adminComplianceFootnoteBorder, adminDualMuted, adminLabel, adminMonoNeutralHint, adminMuted, adminPrimary, adminRoleTitle, adminSectionDividerSoft, adminSoft, adminStrong } from '../../../utils/adminThemeClasses';
import { chipVariantClasses, csrRoleAccentClasses } from '../../../utils/chipVariants';
interface PermissionsSectionProps {
  user: User | null;
}

interface Permission {
  key: string;
  displayName: string;
  isReadOnly?: boolean;
  requiresApproval?: boolean;
}

interface PermissionCategory {
  category: string;
  displayName: string;
  icon: string;
  permissions: Permission[];
}

interface RolePermissionsResponse {
  role: {
    key: string;
    displayName: string;
    shortName: string;
    icon: string;
    color: string;
    canApprove: boolean;
    description: string;
  };
  permissionCount: number;
  permissions: PermissionCategory[];
  /** Quelle der Rollendefinition: Parse CSRRole oder statischer Fallback (iOS/Seed-parität). */
  resolution?: {
    source: 'parse_role' | 'static_definition_fallback';
    detail?: string;
  };
}

const PERMISSION_SORT_LOCALE = 'de';

/** Kategorien und Einträge jeweils nach Anzeigename A–Z (deutsch). */
function sortPermissionCategoriesAlphabetically(categories: PermissionCategory[]): PermissionCategory[] {
  return [...categories]
    .map((cat) => ({
      ...cat,
      permissions: [...cat.permissions].sort((a, b) =>
        a.displayName.localeCompare(b.displayName, PERMISSION_SORT_LOCALE, { sensitivity: 'base' }),
      ),
    }))
    .sort((a, b) =>
      a.displayName.localeCompare(b.displayName, PERMISSION_SORT_LOCALE, { sensitivity: 'base' }),
    );
}

export function PermissionsSection({ user }: PermissionsSectionProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const getCSRRoleDisplay = (csrSubRole?: string): { name: string; key: string } => {
    switch (csrSubRole) {
      case 'level_1':
      case 'level1':
        return { name: 'Level 1 Support', key: 'level1' };
      case 'level_2':
      case 'level2':
        return { name: 'Level 2 Support', key: 'level2' };
      case 'fraud_analyst':
      case 'fraudAnalyst':
      case 'fraud':
        return { name: 'Fraud Analyst', key: 'fraud' };
      case 'compliance_officer':
      case 'complianceOfficer':
      case 'compliance':
        return { name: 'Compliance Officer', key: 'compliance' };
      case 'tech_support':
      case 'techSupport':
      case 'tech':
        return { name: 'Tech Support', key: 'techSupport' };
      case 'teamlead':
      case 'team_lead':
      case 'lead':
        return { name: 'Team Lead', key: 'teamlead' };
      default:
        return { name: 'Customer Service', key: 'level1' };
    }
  };

  const queryClient = useQueryClient();
  const roleDisplay = getCSRRoleDisplay(user?.csrSubRole);
  const roleBadgeClass = csrRoleAccentClasses(user?.csrSubRole, isDark);

  // Invalidate cache when user changes
  useEffect(() => {
    if (user?.objectId) {
      queryClient.invalidateQueries({ queryKey: ['csrRolePermissions'] });
    }
  }, [user?.objectId, user?.csrSubRole, queryClient]);

  // Fetch permissions for the user's role
  const { data: rolePermissions, isLoading, error, refetch } = useQuery<RolePermissionsResponse>({
    queryKey: ['csrRolePermissions', user?.objectId, roleDisplay.key], // Include user ID to prevent caching across users
    queryFn: async () => {
      const result = await cloudFunction<RolePermissionsResponse>('getCSRRolePermissions', {
        roleKey: roleDisplay.key,
      });
      return result;
    },
    enabled: !!user && !!user.csrSubRole,
    staleTime: 0, // Don't cache - always fetch fresh
    gcTime: 0, // Don't keep in garbage collection cache
    refetchOnMount: 'always', // Always refetch when component mounts
    refetchOnWindowFocus: true, // Refetch when window gets focus
    retry: 2,
  });

  // Force refetch when roleKey changes
  useEffect(() => {
    if (user?.csrSubRole && roleDisplay.key) {
      refetch();
    }
  }, [roleDisplay.key, user?.csrSubRole, refetch]);

  // Category icon mapping (fallback for text-based icons from backend)
  const getCategoryIcon = (category: string): string => {
    const icons: Record<string, string> = {
      viewing: '👁️',
      modification: '✏️',
      support: '💬',
      compliance: '📋',
      fraud: '🔍',
      administration: '⚙️',
    };
    return icons[category] || '📄';
  };

  const sortedPermissionCategories = useMemo(() => {
    if (!rolePermissions?.permissions?.length) return [];
    return sortPermissionCategoriesAlphabetically(rolePermissions.permissions);
  }, [rolePermissions]);

  return (
    <Card>
      <div className="flex items-center gap-2 mb-4">
        <svg
          className={clsx('w-5 h-5', isDark ? 'text-orange-400' : 'text-orange-600')}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"
          />
        </svg>
        <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
          Meine Berechtigungen
        </h2>
      </div>

      {user && (
        <div className="mb-4">
          <div
            className={clsx(
              'flex items-center justify-between gap-3 p-3 rounded-lg border',
              isDark ? 'bg-slate-800/90 border-slate-600' : 'bg-gray-50 border-gray-200/80',
            )}
          >
            <div className="min-w-0">
              <div
                className={clsx('text-xs mb-1', adminMuted(isDark))}
              >
                Aktuelle Rolle
              </div>
              <div
                className={clsx(
                  'font-semibold',
                  adminRoleTitle(isDark),
                )}
              >
                {roleDisplay.name}
              </div>
              <div
                className={clsx('text-xs mt-1 font-mono', adminMonoNeutralHint(isDark))}
              >
                csrSubRole: {user.csrSubRole || 'nicht gesetzt'} → CSRRole.key: {roleDisplay.key}
                {' '}(Kurz: L1, L2, Fraud, Compliance, Tech, Lead)
              </div>
            </div>
            <span className={clsx('font-bold flex-shrink-0', roleBadgeClass)}>
              {user.csrSubRole?.toUpperCase() || 'CSR'}
            </span>
          </div>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="flex items-center justify-center py-4">
          <div className="animate-spin w-5 h-5 border-2 border-orange-600 border-t-transparent rounded-full" />
          <span className={clsx('ml-2 text-sm', adminMuted(isDark))}>
            Berechtigungen werden geladen...
          </span>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div
          className={clsx(
            'text-sm p-3 rounded-lg border',
            isDark
              ? 'text-red-200 bg-red-950/50 border-red-800/60'
              : 'text-red-600 bg-red-50 border-red-100',
          )}
        >
          Fehler beim Laden der Berechtigungen: {error instanceof Error ? error.message : 'Unbekannter Fehler'}
        </div>
      )}

      {rolePermissions?.resolution?.source === 'static_definition_fallback' && rolePermissions.resolution.detail && (
        <div
          className={clsx(
            'text-sm p-3 rounded-lg border mb-3',
            isDark
              ? 'text-amber-100 bg-amber-950/40 border-amber-800/50'
              : 'text-amber-900 bg-amber-50 border-amber-200',
          )}
          role="status"
        >
          <span className="font-medium">Hinweis (Parse): </span>
          {rolePermissions.resolution.detail}
        </div>
      )}

      {/* Permissions List */}
      {rolePermissions && rolePermissions.permissions && rolePermissions.permissions.length > 0 ? (
        <div className="space-y-4">
          {/* Permission Count Summary */}
          <div
            className={clsx(
              'text-sm pb-2 border-b',
              adminSectionDividerSoft(isDark),
            )}
          >
            <span className="font-medium">{rolePermissions.role.shortName}</span>
            {' · '}
            <span className="font-medium">{rolePermissions.permissionCount}</span> Berechtigungen aktiv
            {rolePermissions.role.canApprove && (
              <span className={clsx('ml-2', chipVariantClasses('success', isDark))}>
                ✓ Kann genehmigen
              </span>
            )}
          </div>

          {/* Permissions by Category (alphabetisch) */}
          {sortedPermissionCategories.map((category) => (
            <div
              key={category.category}
              className={clsx('border-b pb-3 last:border-0', adminBorderChromeSoft(isDark))}
            >
              <div className="flex items-center gap-2 mb-2">
                <span className="text-base">{getCategoryIcon(category.category)}</span>
                <h3
                  className={clsx('text-sm font-semibold', adminStrong(isDark))}
                >
                  {category.displayName}
                </h3>
                <span className={clsx('text-xs', adminCaption(isDark))}>
                  ({category.permissions.length})
                </span>
              </div>
              <ul className="space-y-1 ml-6">
                {category.permissions.map((perm) => (
                  <li key={perm.key} className="flex items-center text-sm flex-wrap gap-x-1">
                    <span className="w-2 h-2 rounded-full bg-green-500 mr-2 flex-shrink-0" />
                    <span className={clsx(adminLabel(isDark))}>
                      {perm.displayName}
                    </span>
                    {perm.isReadOnly && (
                      <span
                        className={clsx(
                          'ml-2 text-xs',
                          isDark ? 'text-sky-300' : 'text-blue-600',
                        )}
                        title="Nur Lesezugriff"
                      >
                        (nur lesen)
                      </span>
                    )}
                    {perm.requiresApproval && (
                      <span
                        className={clsx(
                          'ml-2 text-xs',
                          isDark ? 'text-amber-300' : 'text-orange-600',
                        )}
                        title="Erfordert Genehmigung"
                      >
                        (4-Augen)
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      ) : !isLoading ? (
        <div className={clsx('text-sm', adminSoft(isDark))}>
          <p>
            Als {roleDisplay.name} haben Sie Zugriff auf Kundendaten, Ticket-Management und
            Support-Funktionen entsprechend Ihrer Rolle.
          </p>
          <p className={clsx('mt-2 text-xs', adminDualMuted(isDark))}>
            Alle Aktionen werden für Compliance-Zwecke protokolliert.
          </p>
        </div>
      ) : null}

      {/* Compliance Note */}
      {rolePermissions && rolePermissions.permissions && rolePermissions.permissions.length > 0 && (
        <p
          className={clsx(
            'mt-4 text-xs border-t pt-3',
            adminComplianceFootnoteBorder(isDark),
          )}
        >
          Alle Aktionen werden für Compliance-Zwecke protokolliert.
        </p>
      )}
    </Card>
  );
}
