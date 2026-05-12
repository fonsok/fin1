import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '../test/test-utils';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DashboardPage } from './Dashboard';

// Mock AuthContext
const mockUseAuth = vi.fn();
vi.mock('../context/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}));

// Mock usePermissions
const mockUsePermissions = vi.fn();
vi.mock('../hooks/usePermissions', () => ({
  usePermissions: () => mockUsePermissions(),
}));

// Mock admin API
vi.mock('../api/admin', () => ({
  getAdminDashboard: vi.fn(),
}));

import { getAdminDashboard } from '../api/admin';

const mockStats = {
  users: {
    total: 1000,
    active: 850,
    pending: 100,
    suspended: 50,
  },
  tickets: {
    open: 25,
    pending: 10,
    resolved: 115,
  },
  compliance: {
    pendingReviews: 10,
    pendingApprovals: 5,
  },
};

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

describe('DashboardPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockUseAuth.mockReturnValue({
      user: {
        firstName: 'Admin',
        email: 'admin@test.com',
        role: 'admin',
      },
    });
    mockUsePermissions.mockReturnValue({
      roleDescription: 'Administrator',
      canViewTickets: true,
      canViewCompliance: true,
      canApprove4Eyes: true,
      canViewUsers: true,
      canViewAuditLogs: true,
    });
    vi.mocked(getAdminDashboard).mockResolvedValue(mockStats);
  });

  it('renders welcome header with user name', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    expect(screen.getByText(/Willkommen, Admin!/)).toBeInTheDocument();
  });

  it('shows email username when firstName is not available', async () => {
    mockUseAuth.mockReturnValue({
      user: {
        email: 'testuser@test.com',
      },
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    expect(screen.getByText(/Willkommen, testuser!/)).toBeInTheDocument();
  });

  it('displays role description', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    expect(screen.getByText(/Administrator/)).toBeInTheDocument();
  });

  it('shows loading skeleton while fetching data', async () => {
    vi.mocked(getAdminDashboard).mockImplementation(
      () => new Promise(() => {}) // Never resolves
    );

    render(<DashboardPage />, { wrapper: createWrapper() });

    // Should show 4 loading skeletons
    const skeletons = document.querySelectorAll('.animate-pulse');
    expect(skeletons.length).toBe(4);
  });

  it('displays stats after loading', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Benutzer gesamt')).toBeInTheDocument();
    });

    expect(screen.getByText('1.000')).toBeInTheDocument(); // Total users
    expect(screen.getByText('850')).toBeInTheDocument(); // Active
    expect(screen.getByText('100')).toBeInTheDocument(); // Pending
    expect(screen.getByText('50')).toBeInTheDocument(); // Suspended
  });

  it('shows error state when fetch fails', async () => {
    vi.mocked(getAdminDashboard).mockRejectedValue(new Error('API Error'));

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Fehler beim Laden der Statistiken')).toBeInTheDocument();
    });
  });

  it('hides tickets section for full admin (no ticket menu)', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Schnellzugriff')).toBeInTheDocument();
    });

    expect(screen.queryByText('Offene Tickets')).not.toBeInTheDocument();
    expect(screen.queryByText('Alle Tickets anzeigen →')).not.toBeInTheDocument();
  });

  it('shows tickets section for business_admin when canViewTickets', async () => {
    mockUseAuth.mockReturnValue({
      user: {
        firstName: 'Finance',
        email: 'finance@test.com',
        role: 'business_admin',
      },
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Offene Tickets')).toBeInTheDocument();
    });

    expect(screen.getByText('Alle Tickets anzeigen →')).toBeInTheDocument();
  });

  it('hides tickets section when user cannot view tickets', async () => {
    mockUsePermissions.mockReturnValue({
      roleDescription: 'Limited',
      canViewTickets: false,
      canViewCompliance: false,
      canApprove4Eyes: false,
      canViewUsers: false,
      canViewAuditLogs: false,
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Schnellzugriff')).toBeInTheDocument();
    });

    expect(screen.queryByText('Offene Tickets')).not.toBeInTheDocument();
  });

  it('shows compliance section when user can view compliance', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Compliance-Reviews')).toBeInTheDocument();
    });

    expect(screen.getByText('Compliance-Events anzeigen →')).toBeInTheDocument();
  });

  it('shows approvals section when user can approve', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('4-Augen-Freigaben')).toBeInTheDocument();
    });

    expect(screen.getByText('Freigaben anzeigen →')).toBeInTheDocument();
  });

  it('shows quick actions', async () => {
    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Schnellzugriff')).toBeInTheDocument();
    });

    expect(screen.getByText('Benutzer suchen')).toBeInTheDocument();
    expect(screen.getByText('Audit-Logs')).toBeInTheDocument();
  });

  it('hides user search when user cannot view users', async () => {
    mockUsePermissions.mockReturnValue({
      roleDescription: 'Limited',
      canViewTickets: false,
      canViewCompliance: false,
      canApprove4Eyes: false,
      canViewUsers: false,
      canViewAuditLogs: false,
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Schnellzugriff')).toBeInTheDocument();
    });

    expect(screen.queryByText('Benutzer suchen')).not.toBeInTheDocument();
  });

  it('displays ticket count badge for business_admin', async () => {
    vi.mocked(getAdminDashboard).mockResolvedValue(mockStats);
    mockUseAuth.mockReturnValue({
      user: { firstName: 'Finance', email: 'f@test.com', role: 'business_admin' },
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Offene Tickets')).toBeInTheDocument();
    });
    await waitFor(() => {
      expect(screen.getByText('25')).toBeInTheDocument();
    });
  });

  it('shows message when no open tickets (business_admin)', async () => {
    vi.mocked(getAdminDashboard).mockResolvedValue({
      ...mockStats,
      tickets: { open: 0, pending: 5, resolved: 95 },
    });
    mockUseAuth.mockReturnValue({
      user: { firstName: 'Finance', email: 'f@test.com', role: 'business_admin' },
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Keine offenen Tickets')).toBeInTheDocument();
    });
  });

  it('shows message when all compliance events reviewed', async () => {
    vi.mocked(getAdminDashboard).mockResolvedValue({
      ...mockStats,
      compliance: { pendingReviews: 0, pendingApprovals: 0 },
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Alle Events geprüft')).toBeInTheDocument();
    });
  });

  it('shows message when no pending approvals', async () => {
    vi.mocked(getAdminDashboard).mockResolvedValue({
      ...mockStats,
      compliance: { pendingReviews: 10, pendingApprovals: 0 },
    });

    render(<DashboardPage />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('Keine ausstehenden Freigaben')).toBeInTheDocument();
    });
  });
});
