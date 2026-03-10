import { useEffect } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Card } from '../../../components/ui';
import { cloudFunction } from '../../../api/parse';
import type { User } from '../../../context/AuthContext';

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

export function PermissionsSection({ user }: PermissionsSectionProps) {
  const getCSRRoleDisplay = (csrSubRole?: string): { name: string; color: string; key: string } => {
    switch (csrSubRole) {
      case 'level_1':
      case 'level1':
        return { name: 'Level 1 Support', color: 'bg-blue-100 text-blue-800', key: 'level1' };
      case 'level_2':
      case 'level2':
        return { name: 'Level 2 Support', color: 'bg-green-100 text-green-800', key: 'level2' };
      case 'fraud_analyst':
      case 'fraudAnalyst':
      case 'fraud':
        return { name: 'Fraud Analyst', color: 'bg-red-100 text-red-800', key: 'fraud' };
      case 'compliance_officer':
      case 'complianceOfficer':
      case 'compliance':
        return { name: 'Compliance Officer', color: 'bg-purple-100 text-purple-800', key: 'compliance' };
      case 'tech_support':
      case 'techSupport':
        return { name: 'Tech Support', color: 'bg-yellow-100 text-yellow-800', key: 'techSupport' };
      case 'teamlead':
        return { name: 'Team Lead', color: 'bg-indigo-100 text-indigo-800', key: 'teamlead' };
      default:
        return { name: 'Customer Service', color: 'bg-gray-100 text-gray-800', key: 'level1' };
    }
  };

  const queryClient = useQueryClient();
  const roleDisplay = getCSRRoleDisplay(user?.csrSubRole);

  // Debug: Log the user's csrSubRole and resolved roleKey
  console.log('[PermissionsSection] user.csrSubRole:', user?.csrSubRole, '-> roleKey:', roleDisplay.key);

  // Invalidate cache when user changes
  useEffect(() => {
    if (user?.objectId) {
      console.log('[PermissionsSection] User changed, invalidating cache');
      queryClient.invalidateQueries({ queryKey: ['csrRolePermissions'] });
    }
  }, [user?.objectId, user?.csrSubRole, queryClient]);

  // Fetch permissions for the user's role
  const { data: rolePermissions, isLoading, error, refetch } = useQuery<RolePermissionsResponse>({
    queryKey: ['csrRolePermissions', user?.objectId, roleDisplay.key], // Include user ID to prevent caching across users
    queryFn: async () => {
      console.log('[PermissionsSection] Fetching permissions for roleKey:', roleDisplay.key);
      const result = await cloudFunction<RolePermissionsResponse>('getCSRRolePermissions', {
        roleKey: roleDisplay.key
      });
      console.log('[PermissionsSection] Got permissions:', result?.permissionCount);
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
      console.log('[PermissionsSection] Role key changed, refetching:', roleDisplay.key);
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

  return (
    <Card>
      <div className="flex items-center gap-2 mb-4">
        <svg
          className="w-5 h-5 text-orange-600"
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
        <h2 className="text-lg font-semibold">Meine Berechtigungen</h2>
      </div>

      {user && (
        <div className="mb-4">
          <div className="flex items-center justify-between p-3 rounded-lg bg-gray-50">
            <div>
              <div className="text-xs text-gray-500 mb-1">Aktuelle Rolle</div>
              <div className="font-semibold text-gray-900">{roleDisplay.name}</div>
              <div className="text-xs text-gray-400 mt-1">
                csrSubRole: {user.csrSubRole || 'nicht gesetzt'} → key: {roleDisplay.key}
              </div>
            </div>
            <span className={`px-3 py-1 text-xs font-bold rounded ${roleDisplay.color}`}>
              {user.csrSubRole?.toUpperCase() || 'CSR'}
            </span>
          </div>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="flex items-center justify-center py-4">
          <div className="animate-spin w-5 h-5 border-2 border-orange-600 border-t-transparent rounded-full" />
          <span className="ml-2 text-sm text-gray-500">Berechtigungen werden geladen...</span>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="text-sm text-red-600 bg-red-50 p-3 rounded-lg">
          Fehler beim Laden der Berechtigungen: {error instanceof Error ? error.message : 'Unbekannter Fehler'}
        </div>
      )}

      {/* Permissions List */}
      {rolePermissions && rolePermissions.permissions && rolePermissions.permissions.length > 0 ? (
        <div className="space-y-4">
          {/* Permission Count Summary */}
          <div className="text-sm text-gray-600 pb-2 border-b">
            <span className="font-medium">{rolePermissions.permissionCount}</span> Berechtigungen aktiv
            {rolePermissions.role.canApprove && (
              <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                ✓ Kann genehmigen
              </span>
            )}
          </div>

          {/* Permissions by Category */}
          {rolePermissions.permissions.map((category) => (
            <div key={category.category} className="border-b border-gray-100 pb-3 last:border-0">
              <div className="flex items-center gap-2 mb-2">
                <span className="text-base">{getCategoryIcon(category.category)}</span>
                <h3 className="text-sm font-semibold text-gray-700">{category.displayName}</h3>
                <span className="text-xs text-gray-400">({category.permissions.length})</span>
              </div>
              <ul className="space-y-1 ml-6">
                {category.permissions.map((perm) => (
                  <li key={perm.key} className="flex items-center text-sm">
                    <span className="w-2 h-2 rounded-full bg-green-500 mr-2 flex-shrink-0" />
                    <span className="text-gray-700">{perm.displayName}</span>
                    {perm.isReadOnly && (
                      <span className="ml-2 text-xs text-blue-600" title="Nur Lesezugriff">
                        (nur lesen)
                      </span>
                    )}
                    {perm.requiresApproval && (
                      <span className="ml-2 text-xs text-orange-600" title="Erfordert Genehmigung">
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
        <div className="text-sm text-gray-600">
          <p>
            Als {roleDisplay.name} haben Sie Zugriff auf Kundendaten, Ticket-Management und
            Support-Funktionen entsprechend Ihrer Rolle.
          </p>
          <p className="mt-2 text-xs text-gray-500">
            Alle Aktionen werden für Compliance-Zwecke protokolliert.
          </p>
        </div>
      ) : null}

      {/* Compliance Note */}
      {rolePermissions && rolePermissions.permissions && rolePermissions.permissions.length > 0 && (
        <p className="mt-4 text-xs text-gray-500 border-t pt-3">
          Alle Aktionen werden für Compliance-Zwecke protokolliert.
        </p>
      )}
    </Card>
  );
}
