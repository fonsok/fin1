import clsx from 'clsx';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { useTheme } from './context/ThemeContext';
import { Layout } from './components/Layout';
import { CSRRedirectGuard } from './components/CSRRedirectGuard';
import { LoginPage } from './pages/Login';
import { DashboardPage } from './pages/Dashboard';
import { UserListPage, UserDetailPage } from './pages/Users';
import { TicketListPage } from './pages/Tickets';
import { ComplianceEventsPage } from './pages/Compliance';
import { ApprovalsListPage } from './pages/Approvals';
import { AuditLogsPage } from './pages/Audit';
import { FinanceDashboardPage } from './pages/Finance';
import { SecurityDashboardPage } from './pages/Security';
import { SettingsPage } from './pages/Settings';
import { ConfigurationPage } from './pages/Configuration';
import { SystemHealthPage } from './pages/System';
import { TemplatesPage } from './pages/Templates';
import { FAQsPage } from './pages/FAQs';
import { TermsPage } from './pages/Terms';
import { OnboardingFunnelPage } from './pages/Onboarding';
import { SummaryReportPage, AppLedgerPage, DocumentSearchPage } from './pages/Reports';
import { KYBReviewPage } from './pages/KYBReview/KYBReviewPage';
import { CSRApp } from './csr-portal/CSRApp';

// Protected Route Wrapper for ADMIN routes only
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading, needs2FAVerification, user } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (isLoading) {
    return (
      <div
        className={clsx(
          'min-h-screen flex items-center justify-center',
          isDark ? 'bg-slate-900' : 'bg-gray-50',
        )}
      >
        <div className="text-center">
          <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          <p className={clsx('mt-4', isDark ? 'text-slate-400' : 'text-gray-500')}>Laden...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated && !needs2FAVerification) {
    return <Navigate to="/login" replace />;
  }

  // CRITICAL: Block CSR users from accessing admin routes - redirect to CSR portal
  if (isAuthenticated && user?.role === 'customer_service') {
    return <Navigate to="/csr" replace />;
  }

  // Block non-admin roles
  if (isAuthenticated && user?.role !== 'admin' && user?.role !== 'business_admin' && user?.role !== 'security_officer' && user?.role !== 'compliance') {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

// Public Route Wrapper (redirects to dashboard if already authenticated)
function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading, user } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (isLoading) {
    return (
      <div
        className={clsx(
          'min-h-screen flex items-center justify-center',
          isDark ? 'bg-slate-900' : 'bg-gray-50',
        )}
      >
        <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
      </div>
    );
  }

  if (isAuthenticated) {
    // Redirect CSR users to CSR portal, admin users to admin dashboard
    if (user?.role === 'customer_service') {
      return <Navigate to="/csr" replace />;
    }
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      {/* CSR Portal Routes - Separate App */}
      <Route path="/csr/*" element={<CSRApp />} />

        {/* Admin Portal Routes */}
        <Route
          path="/login"
          element={
            <PublicRoute>
              <LoginPage />
            </PublicRoute>
          }
        />

        {/* Protected Admin Routes */}
        <Route
          path="/*"
          element={
            <CSRRedirectGuard>
              <ProtectedRoute>
                <Layout>
                  <Routes>
                    <Route path="/" element={<DashboardPage />} />
                    <Route path="/users" element={<UserListPage />} />
                    <Route path="/users/:userId" element={<UserDetailPage />} />
                    <Route path="/tickets" element={<TicketListPage />} />
                    <Route path="/onboarding" element={<OnboardingFunnelPage />} />
                    <Route path="/compliance" element={<ComplianceEventsPage />} />
                    <Route path="/finance" element={<FinanceDashboardPage />} />
                    <Route path="/security" element={<SecurityDashboardPage />} />
                    <Route path="/approvals" element={<ApprovalsListPage />} />
                    <Route path="/kyb-review" element={<KYBReviewPage />} />
                    <Route path="/audit" element={<AuditLogsPage />} />
                    <Route path="/configuration" element={<ConfigurationPage />} />
                    <Route path="/reports" element={<SummaryReportPage />} />
                    <Route path="/bank-ledger" element={<Navigate to="/app-ledger" replace />} />
                    <Route path="/app-ledger" element={<AppLedgerPage />} />
                    <Route path="/documents" element={<DocumentSearchPage />} />
                    <Route path="/system" element={<SystemHealthPage />} />
                    <Route path="/templates" element={<TemplatesPage />} />
                    <Route path="/faqs" element={<FAQsPage />} />
                    <Route path="/terms" element={<TermsPage />} />
                    <Route path="/settings" element={<SettingsPage />} />
                    <Route path="*" element={<Navigate to="/" replace />} />
                  </Routes>
                </Layout>
              </ProtectedRoute>
            </CSRRedirectGuard>
          }
        />
    </Routes>
  );
}
