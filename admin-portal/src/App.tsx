import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { Layout } from './components/Layout';
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

// Protected Route Wrapper
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading, needs2FAVerification } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          <p className="mt-4 text-gray-500">Laden...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated && !needs2FAVerification) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

// Public Route Wrapper (redirects to dashboard if already authenticated)
function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      {/* Public Routes */}
      <Route
        path="/login"
        element={
          <PublicRoute>
            <LoginPage />
          </PublicRoute>
        }
      />

      {/* Protected Routes */}
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <Layout>
              <Routes>
                <Route path="/" element={<DashboardPage />} />
                <Route path="/users" element={<UserListPage />} />
                <Route path="/users/:userId" element={<UserDetailPage />} />
                <Route path="/tickets" element={<TicketListPage />} />
                <Route path="/compliance" element={<ComplianceEventsPage />} />
                <Route path="/finance" element={<FinanceDashboardPage />} />
                <Route path="/security" element={<SecurityDashboardPage />} />
                <Route path="/approvals" element={<ApprovalsListPage />} />
                <Route path="/audit" element={<AuditLogsPage />} />
                <Route path="/configuration" element={<ConfigurationPage />} />
                <Route path="/system" element={<SystemHealthPage />} />
                <Route path="/settings" element={<SettingsPage />} />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </Layout>
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}
