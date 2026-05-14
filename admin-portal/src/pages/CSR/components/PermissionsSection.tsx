import { useEffect, useMemo } from 'react';
import clsx from 'clsx';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { cloudFunction } from '../../../api/parse';
import type { User } from '../../../context/AuthContext';

import { adminCaption, adminDualMuted, adminLabel, adminMuted, adminPrimary, adminSoft, adminStrong } from '../../../utils/adminThemeClasses';
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

  const getCSRRoleDisplay = (
    csrSubRole?: string
  ): { name: string; badgeLight: string; badgeDark: string; key: string } => {
    switch (csrSubRole) {
      case 'level_1':
      case 'level1':
        return {
          name: 'Level 1 Support',
          badgeLight: 'bg-blue-100 text-blue-800',
          badgeDark: 'bg-blue-600/30 text-blue-100 border border-blue-500/40',
          key: 'level1',
        };
      case 'level_2':
      case 'level2':
        return {
          name: 'Level 2 Support',
          badgeLight: 'bg-green-100 text-green-800',
          badgeDark: 'bg-emerald-600/30 text-emerald-100 border border-emerald-500/40',
          key: 'level2',
        };
      case 'fraud_analyst':
      case 'fraudAnalyst':
      case 'fraud':
        return {
          name: 'Fraud Analyst',
          badgeLight: 'bg-red-100 text-red-800',
          badgeDark: 'bg-red-600/30 text-red-100 border border-red-500/40',
          key: 'fraud',
        };
      case 'compliance_officer':
      case 'complianceOfficer':
      case 'compliance':
        return {
          name: 'Compliance Officer',
          badgeLight: 'bg-purple-100 text-purple-800',
          badgeDark: 'bg-purple-600/30 text-purple-100 border border-purple-500/40',
          key: 'compliance',
        };
      case 'tech_support':
      case 'techSupport':
        return {
          name: 'Tech Support',
          badgeLight: 'bg-yellow-100 text-yellow-800',
          badgeDark: 'bg-amber-600/30 text-amber-100 border border-amber-500/40',
          key: 'techSupport',
        };
      case 'teamlead':
        return {
          name: 'Team Lead',
          badgeLight: 'bg-indigo-100 text-indigo-800',
          badgeDark: 'bg-indigo-600/30 text-indigo-100 border border-indigo-500/40',
          key: 'teamlead',
        };
      default:
        return {
          name: 'Customer Service',
          badgeLight: clsx('bg-gray-100 text-gray-800'),
          badgeDark: 'bg-slate-600/40 text-slate-100 border border-slate-500/40',
          key: 'level1',
        };
    }
  };

  const queryClient = useQueryClient();
  const roleDisplay = getCSRRoleDisplay(user?.csrSubRole);
  const roleBadgeClass = isDark ? roleDisplay.badgeDark : roleDisplay.badgeLight;

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
                  isDark ? 'text-slate-100' : 'text-neutral-950',
                )}
              >
                {roleDisplay.name}
              </div>
              <div
                className={clsx('text-xs mt-1 font-mono', isDark ? 'text-slate-500' : 'text-neutral-600')}
              >
                csrSubRole: {user.csrSubRole || 'nicht gesetzt'} → key: {roleDisplay.key}
              </div>
            </div>
            <span
              className={clsx(
                'px-3 py-1 text-xs font-bold rounded flex-shrink-0',
                roleBadgeClass,
              )}
            >
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

      {/* Permissions List */}
      {rolePermissions && rolePermissions.permissions && rolePermissions.permissions.length > 0 ? (
        <div className="space-y-4">
          {/* Permission Count Summary */}
          <div
            className={clsx(
              'text-sm pb-2 border-b',
              isDark ? 'text-slate-300 border-slate-600' : 'text-gray-600 border-gray-200',
            )}
          >
            <span className="font-medium">{rolePermissions.permissionCount}</span> Berechtigungen aktiv
            {rolePermissions.role.canApprove && (
              <span
                className={clsx(
                  'ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium',
                  isDark
                    ? 'bg-emerald-600/25 text-emerald-200 border border-emerald-500/35'
                    : 'bg-green-100 text-green-800',
                )}
              >
                ✓ Kann genehmigen
              </span>
            )}
          </div>

          {/* Permissions by Category (alphabetisch) */}
          {sortedPermissionCategories.map((category) => (
            <div
              key={category.category}
              className={clsx('border-b pb-3 last:border-0', isDark ? 'border-slate-600' : 'border-gray-100')}
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
            isDark ? 'text-slate-500 border-slate-600' : 'text-gray-500 border-gray-200',
          )}
        >
          Alle Aktionen werden für Compliance-Zwecke protokolliert.
        </p>
      )}
    </Card>
  );
}
