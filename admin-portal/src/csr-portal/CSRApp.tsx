import { Routes, Route, Navigate, Outlet } from 'react-router-dom';
import clsx from 'clsx';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { CSRLayout } from './components/CSRLayout';
import { CSRLoginPage } from './pages/CSRLogin';
import { CSRDashboard } from '../pages/CSR';
import { TicketListPage } from '../pages/Tickets';
import { TicketDetailPage } from '../pages/CSR/pages/TicketDetail';
import { TicketQueuePage } from '../pages/CSR/pages/TicketQueue';
import { CreateTicketPage } from '../pages/CSR/pages/CreateTicket';
import { CustomerListPage } from '../pages/CSR/pages/CustomerList';
import { CustomerDetailPage } from '../pages/CSR/pages/CustomerDetail';
import { AnalyticsPage } from '../pages/CSR/pages/Analytics';
import { TicketArchivePage } from '../pages/CSR/pages/TicketArchive';
import { BulkOperationsPage } from '../pages/CSR/pages/BulkOperations';
import { KYCStatusPage } from '../pages/CSR/pages/KYCStatus';
import { KYBReviewPage } from '../pages/KYBReview/KYBReviewPage';
import { TrendsPage } from '../pages/CSR/pages/Trends';
import { TemplatesPage } from '../pages/Templates';
import { FAQsPage } from '../pages/FAQs';

// Protected Layout for CSR - wraps all protected routes
function CSRProtectedLayout() {
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
        <div className="text-center">
          <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
          <p className={clsx('mt-4', isDark ? 'text-slate-400' : 'text-gray-500')}>Laden...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/csr/login" replace />;
  }

  // Only allow customer_service role
  if (user?.role !== 'customer_service') {
    return <Navigate to="/login" replace />;
  }

  return (
    <CSRLayout>
      <Outlet />
    </CSRLayout>
  );
}

// Public Route for CSR Login
function CSRLoginWrapper() {
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

  if (isAuthenticated && user?.role === 'customer_service') {
    return <Navigate to="/csr" replace />;
  }

  return <CSRLoginPage />;
}

export function CSRApp() {
  return (
    <Routes>
      {/* CSR Login Page */}
      <Route path="login" element={<CSRLoginWrapper />} />

      {/* CSR Protected Routes with Layout */}
      <Route element={<CSRProtectedLayout />}>
        <Route index element={<CSRDashboard />} />
        <Route path="tickets" element={<TicketListPage />} />
        <Route path="tickets/:ticketId" element={<TicketDetailPage />} />
        <Route path="tickets/queue" element={<TicketQueuePage />} />
        <Route path="tickets/new" element={<CreateTicketPage />} />
        <Route path="tickets/archive" element={<TicketArchivePage />} />
        <Route path="tickets/bulk" element={<BulkOperationsPage />} />
        <Route path="customers" element={<CustomerListPage />} />
        <Route path="customers/:userId" element={<CustomerDetailPage />} />
        <Route path="kyc" element={<KYCStatusPage />} />
        <Route path="kyb" element={<KYBReviewPage />} />
        <Route path="analytics" element={<AnalyticsPage />} />
        <Route path="trends" element={<TrendsPage />} />
        <Route path="templates" element={<TemplatesPage />} />
        <Route path="faqs" element={<FAQsPage />} />
      </Route>

      {/* Catch-all redirect */}
      <Route path="*" element={<Navigate to="/csr" replace />} />
    </Routes>
  );
}
