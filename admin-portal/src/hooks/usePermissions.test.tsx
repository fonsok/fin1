import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import { usePermissions, useNavigation } from './usePermissions';

// Mock the AuthContext
const mockUseAuth = vi.fn();

vi.mock('../context/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}));

describe('usePermissions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns admin role checks for admin user', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'admin' },
      permissions: { isElevated: true, isFullAdmin: true },
      hasPermission: vi.fn().mockReturnValue(true),
    });

    const { result } = renderHook(() => usePermissions());

    expect(result.current.isAdmin).toBe(true);
    expect(result.current.isBusinessAdmin).toBe(false);
    expect(result.current.isElevated).toBe(true);
    expect(result.current.isFullAdmin).toBe(true);
  });

  it('returns business_admin role checks', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'business_admin' },
      permissions: { isElevated: false, isFullAdmin: false },
      hasPermission: vi.fn().mockReturnValue(false),
    });

    const { result } = renderHook(() => usePermissions());

    expect(result.current.isAdmin).toBe(false);
    expect(result.current.isBusinessAdmin).toBe(true);
    expect(result.current.isSecurityOfficer).toBe(false);
  });

  it('returns security_officer role checks', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'security_officer' },
      permissions: { isElevated: false, isFullAdmin: false },
      hasPermission: vi.fn().mockReturnValue(false),
    });

    const { result } = renderHook(() => usePermissions());

    expect(result.current.isSecurityOfficer).toBe(true);
    expect(result.current.isCompliance).toBe(false);
  });

  it('checks feature permissions correctly', () => {
    const mockHasPermission = vi.fn((permission: string) => {
      return ['searchUsers', 'getTickets'].includes(permission);
    });

    mockUseAuth.mockReturnValue({
      user: { role: 'customer_service' },
      permissions: { isElevated: false, isFullAdmin: false },
      hasPermission: mockHasPermission,
    });

    const { result } = renderHook(() => usePermissions());

    expect(result.current.canViewUsers).toBe(true);
    expect(result.current.canViewTickets).toBe(true);
    expect(result.current.canViewFinancials).toBe(false);
    expect(result.current.canViewSecurity).toBe(false);
  });

  it('handles null permissions gracefully', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'admin' },
      permissions: null,
      hasPermission: vi.fn().mockReturnValue(false),
    });

    const { result } = renderHook(() => usePermissions());

    expect(result.current.isElevated).toBe(false);
    expect(result.current.isFullAdmin).toBe(false);
  });
});

describe('useNavigation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns all nav items for admin with full permissions', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'admin' },
      permissions: { isElevated: true, isFullAdmin: true },
      hasPermission: vi.fn().mockReturnValue(true),
    });

    const { result } = renderHook(() => useNavigation());

    expect(result.current.length).toBeGreaterThan(5);
    expect(result.current.map(i => i.id)).toContain('dashboard');
    expect(result.current.map(i => i.id)).toContain('users');
    expect(result.current.map(i => i.id)).toContain('tickets');
    expect(result.current.map(i => i.id)).toContain('finance');
    expect(result.current.map(i => i.id)).toContain('security');
    expect(result.current.map(i => i.id)).toContain('settings');
  });

  it('returns limited nav items for customer_service', () => {
    const mockHasPermission = vi.fn((permission: string) => {
      return ['searchUsers', 'getTickets'].includes(permission);
    });

    mockUseAuth.mockReturnValue({
      user: { role: 'customer_service' },
      permissions: { isElevated: false, isFullAdmin: false },
      hasPermission: mockHasPermission,
    });

    const { result } = renderHook(() => useNavigation());

    const navIds = result.current.map(i => i.id);
    expect(navIds).toContain('dashboard');
    expect(navIds).toContain('users');
    expect(navIds).toContain('tickets');
    expect(navIds).toContain('settings');
    expect(navIds).not.toContain('finance');
    expect(navIds).not.toContain('security');
  });

  it('always includes dashboard and settings', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'compliance' },
      permissions: { isElevated: false, isFullAdmin: false },
      hasPermission: vi.fn().mockReturnValue(false),
    });

    const { result } = renderHook(() => useNavigation());

    const navIds = result.current.map(i => i.id);
    expect(navIds).toContain('dashboard');
    expect(navIds).toContain('settings');
  });

  it('returns correct paths for nav items', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'admin' },
      permissions: { isElevated: true, isFullAdmin: true },
      hasPermission: vi.fn().mockReturnValue(true),
    });

    const { result } = renderHook(() => useNavigation());

    const dashboard = result.current.find(i => i.id === 'dashboard');
    const users = result.current.find(i => i.id === 'users');
    const settings = result.current.find(i => i.id === 'settings');

    expect(dashboard?.path).toBe('/');
    expect(users?.path).toBe('/users');
    expect(settings?.path).toBe('/settings');
  });
});
