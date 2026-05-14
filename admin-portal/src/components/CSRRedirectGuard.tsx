import { useEffect } from 'react';
import clsx from 'clsx';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';

import { adminMuted, adminShellAppBg } from '../utils/adminThemeClasses';
/**
 * Guard component that redirects CSR users away from admin routes
 * This ensures CSR users NEVER see the admin layout
 */
export function CSRRedirectGuard({ children }: { children: React.ReactNode }) {
  const { user, isAuthenticated } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    // If CSR user tries to access admin routes, redirect immediately
    if (isAuthenticated && user?.role === 'customer_service') {
      const path = location.pathname;
      // Only redirect if NOT already on CSR routes
      if (!path.startsWith('/csr') && path !== '/csr/login') {
        console.log('[CSRRedirectGuard] Redirecting CSR user from', path, 'to /csr');
        navigate('/csr', { replace: true });
      }
    }
  }, [isAuthenticated, user?.role, location.pathname, navigate]);

  // Don't render admin content for CSR users
  if (isAuthenticated && user?.role === 'customer_service') {
    const path = location.pathname;
    if (!path.startsWith('/csr') && path !== '/csr/login') {
      // Return loading state while redirecting
      return (
        <div
          className={clsx(
            'min-h-screen flex items-center justify-center',
            adminShellAppBg(isDark),
          )}
        >
          <div className="text-center">
            <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className={clsx('mt-4', adminMuted(isDark))}>
              Weiterleitung zum CSR-Portal...
            </p>
          </div>
        </div>
      );
    }
  }

  return <>{children}</>;
}
