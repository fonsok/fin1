import { useEffect } from 'react';
import clsx from 'clsx';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';

import { adminMuted, adminShellAppBg } from '../utils/adminThemeClasses';

/** Router pathname is basename-relative (`/csr`); `window.location.pathname` may still be `/admin/csr`. */
function isCsrPortalPath(path: string, browserPath: string): boolean {
  return (
    path === '/csr' ||
    path.startsWith('/csr/') ||
    browserPath.endsWith('/csr') ||
    browserPath.includes('/admin/csr/') ||
    browserPath.endsWith('/admin/csr')
  );
}

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
    if (isAuthenticated && user?.role === 'customer_service') {
      const path = location.pathname;
      const browserPath = typeof window !== 'undefined' ? window.location.pathname : path;
      if (!isCsrPortalPath(path, browserPath)) {
        console.log('[CSRRedirectGuard] Redirecting CSR user from', path, browserPath, 'to /csr');
        navigate('/csr', { replace: true });
      }
    }
  }, [isAuthenticated, user?.role, location.pathname, navigate]);

  if (isAuthenticated && user?.role === 'customer_service') {
    const path = location.pathname;
    const browserPath = typeof window !== 'undefined' ? window.location.pathname : path;
    if (!isCsrPortalPath(path, browserPath)) {
      return (
        <div
          className={clsx(
            'min-h-screen flex items-center justify-center',
            adminShellAppBg(isDark),
          )}
        >
          <div className="text-center">
            <div className="animate-spin w-12 h-12 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto" />
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
