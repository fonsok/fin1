import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { login as parseLogin, logout as parseLogout, verify2FA, validateSession, cloudFunction } from '../api/parse';

// ============================================================================
// Types
// ============================================================================

export interface AuthUser {
  objectId: string;
  email: string;
  username: string;
  role: string;
  firstName?: string;
  lastName?: string;
  requires2FA: boolean;
  has2FAEnabled: boolean;
  twoFactorEnabled?: boolean;
  twoFactorEnabledAt?: string;
  twoFactorBackupCodesCount?: number;
  createdAt?: string;
  lastLogin?: string;
}

interface Permissions {
  role: string;
  permissions: string[];
  isFullAdmin: boolean;
  isElevated: boolean;
  roleDescription: string;
}

interface AuthState {
  user: AuthUser | null;
  permissions: Permissions | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  needs2FAVerification: boolean;
}

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  verify2FACode: (code: string) => Promise<void>;
  logout: () => Promise<void>;
  hasPermission: (permission: string) => boolean;
  refreshPermissions: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

// ============================================================================
// Context
// ============================================================================

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Admin roles that require 2FA
const ELEVATED_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance'];
const ADMIN_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance', 'customer_service'];

// ============================================================================
// Provider
// ============================================================================

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null,
    permissions: null,
    isLoading: true,
    isAuthenticated: false,
    needs2FAVerification: false,
  });

  // Check for existing session on mount
  useEffect(() => {
    const checkSession = async () => {
      try {
        const parseUser = await validateSession();

        if (parseUser) {
          const role = parseUser.role as string;

          if (!ADMIN_ROLES.includes(role)) {
            // Not an admin user - log out
            await parseLogout();
            setState({
              user: null,
              permissions: null,
              isLoading: false,
              isAuthenticated: false,
              needs2FAVerification: false,
            });
            return;
          }

          const user: AuthUser = {
            objectId: parseUser.objectId,
            email: parseUser.email,
            username: parseUser.username,
            role: role,
            firstName: parseUser.firstName,
            lastName: parseUser.lastName,
            requires2FA: ELEVATED_ROLES.includes(role),
            has2FAEnabled: parseUser.twoFactorEnabled || false,
          };

          // Check if 2FA verification is needed
          const session2FAVerified = sessionStorage.getItem('2fa_verified') === 'true';
          const needs2FA = user.requires2FA && user.has2FAEnabled && !session2FAVerified;

          if (needs2FA) {
            setState({
              user,
              permissions: null,
              isLoading: false,
              isAuthenticated: false,
              needs2FAVerification: true,
            });
          } else {
            // Fetch permissions
            try {
              const permissions = await cloudFunction<Permissions>('getMyPermissions');
              setState({
                user,
                permissions,
                isLoading: false,
                isAuthenticated: true,
                needs2FAVerification: false,
              });
            } catch (error) {
              console.error('Failed to get permissions:', error);
              setState({
                user,
                permissions: { role: user.role, permissions: [], isFullAdmin: false, isElevated: false, roleDescription: user.role },
                isLoading: false,
                isAuthenticated: true,
                needs2FAVerification: false,
              });
            }
          }
        } else {
          setState({
            user: null,
            permissions: null,
            isLoading: false,
            isAuthenticated: false,
            needs2FAVerification: false,
          });
        }
      } catch (error) {
        console.error('Session check failed:', error);
        setState({
          user: null,
          permissions: null,
          isLoading: false,
          isAuthenticated: false,
          needs2FAVerification: false,
        });
      }
    };

    checkSession();
  }, []);

  // Login function
  const login = useCallback(async (email: string, password: string) => {
    setState(prev => ({ ...prev, isLoading: true }));

    try {
      const parseUser = await parseLogin(email, password);
      const role = parseUser.role as string;

      // Check if user has admin role
      if (!ADMIN_ROLES.includes(role)) {
        await parseLogout();
        throw new Error('Kein Zugriff. Nur Admin-Rollen erlaubt.');
      }

      const user: AuthUser = {
        objectId: parseUser.objectId,
        email: parseUser.email,
        username: parseUser.username,
        role: role,
        firstName: parseUser.firstName,
        lastName: parseUser.lastName,
        requires2FA: ELEVATED_ROLES.includes(role),
        has2FAEnabled: parseUser.twoFactorEnabled || false,
      };

      // Check if 2FA is required
      if (user.requires2FA && user.has2FAEnabled) {
        setState({
          user,
          permissions: null,
          isLoading: false,
          isAuthenticated: false,
          needs2FAVerification: true,
        });
      } else {
        // No 2FA required or not set up
        try {
          const permissions = await cloudFunction<Permissions>('getMyPermissions');
          setState({
            user,
            permissions,
            isLoading: false,
            isAuthenticated: true,
            needs2FAVerification: false,
          });
        } catch (error) {
          console.error('Failed to get permissions:', error);
          setState({
            user,
            permissions: { role: user.role, permissions: [], isFullAdmin: role === 'admin', isElevated: ELEVATED_ROLES.includes(role), roleDescription: user.role },
            isLoading: false,
            isAuthenticated: true,
            needs2FAVerification: false,
          });
        }
      }
    } catch (error) {
      setState(prev => ({ ...prev, isLoading: false }));
      throw error;
    }
  }, []);

  // Verify 2FA code
  const verify2FACode = useCallback(async (code: string) => {
    if (!state.user) throw new Error('Not logged in');

    setState(prev => ({ ...prev, isLoading: true }));

    try {
      const result = await verify2FA(code);

      if (result.verified) {
        // Mark 2FA as verified for this session
        sessionStorage.setItem('2fa_verified', 'true');

        // Fetch permissions
        const permissions = await cloudFunction<Permissions>('getMyPermissions');

        setState(prev => ({
          ...prev,
          permissions,
          isLoading: false,
          isAuthenticated: true,
          needs2FAVerification: false,
        }));
      } else {
        throw new Error('Ungültiger Code');
      }
    } catch (error) {
      setState(prev => ({ ...prev, isLoading: false }));
      throw error;
    }
  }, [state.user]);

  // Logout function
  const logout = useCallback(async () => {
    await parseLogout();
    sessionStorage.removeItem('2fa_verified');
    setState({
      user: null,
      permissions: null,
      isLoading: false,
      isAuthenticated: false,
      needs2FAVerification: false,
    });
  }, []);

  // Check permission
  const hasPermission = useCallback((permission: string): boolean => {
    if (!state.permissions) return false;
    if (state.permissions.isFullAdmin) return true;
    return state.permissions.permissions.includes(permission);
  }, [state.permissions]);

  // Refresh permissions
  const refreshPermissions = useCallback(async () => {
    if (!state.user) return;

    try {
      const permissions = await cloudFunction<Permissions>('getMyPermissions');
      setState(prev => ({ ...prev, permissions }));
    } catch (error) {
      console.error('Failed to refresh permissions:', error);
    }
  }, [state.user]);

  // Refresh user data (for 2FA status updates)
  const refreshUser = useCallback(async () => {
    try {
      const parseUser = await validateSession();
      if (parseUser && state.user) {
        const updatedUser: AuthUser = {
          ...state.user,
          twoFactorEnabled: parseUser.twoFactorEnabled || false,
          twoFactorEnabledAt: parseUser.twoFactorEnabledAt,
          twoFactorBackupCodesCount: parseUser.twoFactorBackupCodes?.length,
          has2FAEnabled: parseUser.twoFactorEnabled || false,
        };
        setState(prev => ({ ...prev, user: updatedUser }));
      }
    } catch (error) {
      console.error('Failed to refresh user:', error);
    }
  }, [state.user]);

  const value: AuthContextType = {
    ...state,
    login,
    verify2FACode,
    logout,
    hasPermission,
    refreshPermissions,
    refreshUser,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

// ============================================================================
// Hook
// ============================================================================

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
