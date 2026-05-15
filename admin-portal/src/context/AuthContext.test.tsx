import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import { AuthProvider, useAuth } from './AuthContext';

// Mock API functions — keep real helpers (resolvePortalRole, normalizePortalRole) from parse.ts
vi.mock('../api/parse', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../api/parse')>();
  return {
    ...actual,
    login: vi.fn(),
    logout: vi.fn(),
    verify2FA: vi.fn(),
    validateSession: vi.fn(),
    cloudFunction: vi.fn(),
  };
});

import * as parseApi from '../api/parse';

const mockParseSessionUser = {
  objectId: 'admin123',
  email: 'admin@test.com',
  username: 'admin@test.com',
  role: 'admin',
  firstName: 'Admin',
  lastName: 'User',
  twoFactorEnabled: false,
};

const mockAdminLoginResult = {
  ...mockParseSessionUser,
  sessionToken: 'session-mock-123',
};

const mockPermissions = {
  role: 'admin',
  permissions: ['searchUsers', 'getTickets', 'getComplianceEvents'],
  isFullAdmin: true,
  isElevated: true,
  roleDescription: 'Administrator',
};

function wrapper({ children }: { children: React.ReactNode }) {
  return <AuthProvider>{children}</AuthProvider>;
}

describe('AuthContext', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    sessionStorage.clear();
    // Default: no existing session
    vi.mocked(parseApi.validateSession).mockResolvedValue(null);
  });

  describe('useAuth hook', () => {
    it('throws error when used outside provider', () => {
      // Suppress console.error for this test
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      expect(() => {
        renderHook(() => useAuth());
      }).toThrow('useAuth must be used within an AuthProvider');

      consoleSpy.mockRestore();
    });

    it('initializes with loading state', async () => {
      const { result } = renderHook(() => useAuth(), { wrapper });

      // Initial state may be loading
      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });
    });
  });

  describe('login', () => {
    it('successfully logs in admin user', async () => {
      vi.mocked(parseApi.login).mockResolvedValue(mockAdminLoginResult);
      vi.mocked(parseApi.cloudFunction).mockResolvedValue(mockPermissions);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('admin@test.com', 'password');
      });

      expect(result.current.isAuthenticated).toBe(true);
      expect(result.current.user?.email).toBe('admin@test.com');
      expect(result.current.permissions?.isFullAdmin).toBe(true);
    });

    it('rejects non-admin users', async () => {
      vi.mocked(parseApi.login).mockResolvedValue({
        ...mockAdminLoginResult,
        role: 'investor', // Not an admin role
      });
      vi.mocked(parseApi.logout).mockResolvedValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await expect(
        act(async () => {
          await result.current.login('user@test.com', 'password');
        })
      ).rejects.toThrow('Kein Zugriff. Nur Admin-Rollen erlaubt.');

      expect(parseApi.logout).toHaveBeenCalled();
    });

    it('requires 2FA for elevated roles with 2FA enabled', async () => {
      vi.mocked(parseApi.login).mockResolvedValue({
        ...mockAdminLoginResult,
        twoFactorEnabled: true,
      });

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('admin@test.com', 'password');
      });

      expect(result.current.needs2FAVerification).toBe(true);
      expect(result.current.isAuthenticated).toBe(false);
    });

    it('allows customer_service without 2FA', async () => {
      vi.mocked(parseApi.login).mockResolvedValue({
        ...mockAdminLoginResult,
        role: 'customer_service',
        twoFactorEnabled: false,
      });
      vi.mocked(parseApi.cloudFunction).mockResolvedValue({
        ...mockPermissions,
        role: 'customer_service',
        isFullAdmin: false,
        isElevated: false,
      });

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('support@test.com', 'password');
      });

      expect(result.current.isAuthenticated).toBe(true);
      expect(result.current.needs2FAVerification).toBe(false);
    });
  });

  describe('verify2FACode', () => {
    it('completes login after successful 2FA verification', async () => {
      vi.mocked(parseApi.login).mockResolvedValue({
        ...mockAdminLoginResult,
        twoFactorEnabled: true,
      });
      vi.mocked(parseApi.verify2FA).mockResolvedValue({ verified: true });
      vi.mocked(parseApi.cloudFunction).mockResolvedValue(mockPermissions);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      // First login (triggers 2FA)
      await act(async () => {
        await result.current.login('admin@test.com', 'password');
      });

      expect(result.current.needs2FAVerification).toBe(true);

      // Then verify 2FA
      await act(async () => {
        await result.current.verify2FACode('123456');
      });

      expect(result.current.isAuthenticated).toBe(true);
      expect(result.current.needs2FAVerification).toBe(false);
      // sessionStorage is mocked in setup.ts, so just verify function was called
      expect(sessionStorage.setItem).toHaveBeenCalledWith('2fa_verified', 'true');
    });

    it('throws on invalid 2FA code', async () => {
      vi.mocked(parseApi.login).mockResolvedValue({
        ...mockAdminLoginResult,
        twoFactorEnabled: true,
      });
      vi.mocked(parseApi.verify2FA).mockResolvedValue({ verified: false });

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('admin@test.com', 'password');
      });

      await expect(
        act(async () => {
          await result.current.verify2FACode('000000');
        })
      ).rejects.toThrow('Ungültiger Code');
    });
  });

  describe('logout', () => {
    it('clears auth state', async () => {
      vi.mocked(parseApi.login).mockResolvedValue(mockAdminLoginResult);
      vi.mocked(parseApi.cloudFunction).mockResolvedValue(mockPermissions);
      vi.mocked(parseApi.logout).mockResolvedValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('admin@test.com', 'password');
      });

      expect(result.current.isAuthenticated).toBe(true);

      await act(async () => {
        await result.current.logout();
      });

      expect(result.current.isAuthenticated).toBe(false);
      expect(result.current.user).toBeNull();
      expect(result.current.permissions).toBeNull();
    });

    it('clears 2FA session flag', async () => {
      vi.mocked(parseApi.logout).mockResolvedValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.logout();
      });

      expect(sessionStorage.removeItem).toHaveBeenCalledWith('2fa_verified');
    });
  });

  describe('hasPermission', () => {
    it('returns true for full admin', async () => {
      vi.mocked(parseApi.login).mockResolvedValue(mockAdminLoginResult);
      vi.mocked(parseApi.cloudFunction).mockResolvedValue({
        ...mockPermissions,
        isFullAdmin: true,
      });

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('admin@test.com', 'password');
      });

      expect(result.current.hasPermission('anyPermission')).toBe(true);
      expect(result.current.hasPermission('anotherPermission')).toBe(true);
    });

    it('checks specific permissions for non-full-admin', async () => {
      vi.mocked(parseApi.login).mockResolvedValue({
        ...mockAdminLoginResult,
        role: 'customer_service',
      });
      vi.mocked(parseApi.cloudFunction).mockResolvedValue({
        role: 'customer_service',
        permissions: ['searchUsers', 'getTickets'],
        isFullAdmin: false,
        isElevated: false,
        roleDescription: 'Customer Service',
      });

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      await act(async () => {
        await result.current.login('support@test.com', 'password');
      });

      expect(result.current.hasPermission('searchUsers')).toBe(true);
      expect(result.current.hasPermission('getTickets')).toBe(true);
      expect(result.current.hasPermission('getFinancialDashboard')).toBe(false);
    });

    it('returns false when not authenticated', async () => {
      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => expect(result.current.isLoading).toBe(false));

      expect(result.current.hasPermission('anyPermission')).toBe(false);
    });
  });

  describe('session restoration', () => {
    it('restores session on mount', async () => {
      vi.mocked(parseApi.validateSession).mockResolvedValue(mockParseSessionUser);
      vi.mocked(parseApi.cloudFunction).mockResolvedValue(mockPermissions);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isAuthenticated).toBe(true);
      });

      expect(result.current.user?.email).toBe('admin@test.com');
    });

    it('requires 2FA verification on session restore if not verified', async () => {
      vi.mocked(parseApi.validateSession).mockResolvedValue({
        ...mockParseSessionUser,
        twoFactorEnabled: true,
      });

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.needs2FAVerification).toBe(true);
      });

      expect(result.current.isAuthenticated).toBe(false);
    });

    it('skips 2FA if already verified in session', async () => {
      // Mock sessionStorage.getItem to return 'true' for 2fa_verified
      vi.mocked(sessionStorage.getItem).mockImplementation((key: string) => {
        if (key === '2fa_verified') return 'true';
        return null;
      });
      vi.mocked(parseApi.validateSession).mockResolvedValue({
        ...mockParseSessionUser,
        twoFactorEnabled: true,
      });
      vi.mocked(parseApi.cloudFunction).mockResolvedValue(mockPermissions);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isAuthenticated).toBe(true);
      });

      expect(result.current.needs2FAVerification).toBe(false);
    });
  });
});
