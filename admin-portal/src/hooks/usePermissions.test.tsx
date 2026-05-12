import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import { matchNavItemForPath, usePermissions, useNavigation } from './usePermissions';

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

describe('matchNavItemForPath', () => {
  const items = [
    { id: 'dashboard', label: 'Dashboard', path: '/', icon: 'home', enabled: true },
    { id: 'users', label: 'Benutzer', path: '/users', icon: 'users', enabled: true },
    { id: 'app-ledger', label: 'App Ledger', path: '/app-ledger', icon: 'banknotes', enabled: true },
  ];

  it('resolves nested paths to the longest matching nav entry', () => {
    expect(matchNavItemForPath('/users/abc123', items)?.id).toBe('users');
    expect(matchNavItemForPath('/app-ledger', items)?.id).toBe('app-ledger');
  });

  it('maps root to dashboard', () => {
    expect(matchNavItemForPath('/', items)?.id).toBe('dashboard');
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

  it('enables all nav except locked ids for business_admin (Finance Admin sidebar)', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'business_admin' },
      permissions: { isElevated: true, isFullAdmin: false },
      hasPermission: vi.fn().mockReturnValue(false),
    });

    const { result } = renderHook(() => useNavigation());

    expect(result.current.find((i) => i.id === 'users')?.enabled).toBe(true);
    expect(result.current.find((i) => i.id === 'finance')?.enabled).toBe(true);
    expect(result.current.find((i) => i.id === 'faqs')?.enabled).toBe(true);
    expect(result.current.find((i) => i.id === 'system')?.enabled).toBe(false);
    expect(result.current.find((i) => i.id === 'security')?.enabled).toBe(false);
    expect(result.current.find((i) => i.id === 'onboarding')?.enabled).toBe(false);
    expect(result.current.find((i) => i.id === 'compliance')?.enabled).toBe(false);
    expect(result.current.find((i) => i.id === 'tickets')?.enabled).toBe(true);
  });

  it('lists all sections but disables finance and security without permission', () => {
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
    expect(navIds).toContain('finance');
    expect(navIds).toContain('security');
    expect(result.current.find(i => i.id === 'finance')?.enabled).toBe(false);
    expect(result.current.find(i => i.id === 'security')?.enabled).toBe(false);
    expect(result.current.find(i => i.id === 'users')?.enabled).toBe(true);
  });

  it('always includes dashboard and settings; compliance entry visible but may be disabled', () => {
    mockUseAuth.mockReturnValue({
      user: { role: 'compliance' },
      permissions: { isElevated: false, isFullAdmin: false },
      hasPermission: vi.fn().mockReturnValue(false),
    });

    const { result } = renderHook(() => useNavigation());

    const navIds = result.current.map(i => i.id);
    expect(navIds).toContain('dashboard');
    expect(navIds).toContain('settings');
    expect(navIds).toContain('compliance');
    expect(result.current.find(i => i.id === 'compliance')?.enabled).toBe(false);
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
