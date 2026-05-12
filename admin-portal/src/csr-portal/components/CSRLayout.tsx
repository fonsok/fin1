import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { getSidebarRoleSubtitle } from '../../utils/format';
import clsx from 'clsx';

interface CSRLayoutProps {
  children: React.ReactNode;
}

export function CSRLayout({ children }: CSRLayoutProps) {
  const { user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { theme, toggleTheme } = useTheme();
  const isDark = theme === 'dark';

  const handleLogout = async () => {
    await logout();
    navigate('/csr/login');
  };

  const navItems = [
    {
      id: 'dashboard',
      label: 'Dashboard',
      path: '/csr',
      icon: 'home',
    },
    {
      id: 'tickets',
      label: 'Tickets',
      path: '/csr/tickets',
      icon: 'ticket',
    },
    {
      id: 'queue',
      label: 'Warteschlange',
      path: '/csr/tickets/queue',
      icon: 'queue',
    },
    {
      id: 'customers',
      label: 'Kunden',
      path: '/csr/customers',
      icon: 'users',
    },
    {
      id: 'kyc',
      label: 'KYC-Status',
      path: '/csr/kyc',
      icon: 'shield-check',
    },
    {
      id: 'kyb',
      label: 'KYB-Status',
      path: '/csr/kyb',
      icon: 'building-office',
    },
    {
      id: 'analytics',
      label: 'Analytics',
      path: '/csr/analytics',
      icon: 'chart',
    },
    {
      id: 'trends',
      label: 'Trends',
      path: '/csr/trends',
      icon: 'trend',
    },
    {
      id: 'templates',
      label: 'Templates',
      path: '/csr/templates',
      icon: 'document-text',
    },
    {
      id: 'faqs',
      label: 'Hilfe & Anleitung',
      path: '/csr/faqs',
      icon: 'question-mark-circle',
    },
  ];

  return (
    <div className={clsx('min-h-screen', isDark ? 'bg-slate-800' : 'bg-gray-50')}>
      {/* Sidebar */}
      <aside
        className={clsx(
          'fixed inset-y-0 left-0 z-50 w-64 bg-gradient-to-b from-fin1-primary to-fin1-secondary transform transition-transform duration-300 ease-in-out lg:translate-x-0',
          sidebarOpen ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        {/* Logo */}
        <div className="h-16 flex items-center px-6 border-b border-white/20">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center shadow-lg">
              <svg className="w-6 h-6 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
            <div>
              <span className="text-lg font-bold text-white">CSR Portal</span>
              <p className="text-xs text-white/80">Kundenservice</p>
            </div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="mt-6 px-3">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.id}
                to={item.path}
                onClick={() => setSidebarOpen(false)}
                className={clsx(
                  'flex items-center gap-3 px-3 py-2.5 rounded-lg mb-1 transition-colors',
                  isActive
                    ? 'bg-white/20 text-white shadow-md'
                    : 'text-white/80 hover:bg-white/10 hover:text-white'
                )}
              >
                <CSRNavIcon name={item.icon} />
                <span className="font-medium">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* User Info (Bottom) */}
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-white/20">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
              <span className="text-white font-medium">
                {user?.firstName?.[0] || user?.email?.[0]?.toUpperCase() || 'C'}
              </span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">
                {user?.firstName || user?.email}
              </p>
              <p className="text-xs text-white/60 truncate">
                {user ? getSidebarRoleSubtitle(user) : ''}
              </p>
            </div>
            <button
              onClick={handleLogout}
              className="p-2 text-white/60 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
              title="Abmelden"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
            </button>
          </div>
        </div>
      </aside>

      {/* Mobile Overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main Content */}
      <div className={clsx('lg:pl-64', isDark ? 'bg-slate-800' : 'bg-gray-50')}>
        {/* Top Bar */}
        <header
          className={clsx(
            'h-16 border-b flex items-center px-4 lg:px-6 shadow-sm',
            isDark ? 'bg-slate-700/80 border-slate-600' : 'bg-white border-gray-200',
          )}
        >
          {/* Mobile Menu Button */}
          <button
            onClick={() => setSidebarOpen(true)}
            className={clsx(
              'lg:hidden p-2 -ml-2',
              isDark ? 'text-slate-300 hover:text-white' : 'text-gray-600 hover:text-gray-900',
            )}
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          {/* Page Title */}
          <div className="flex-1 ml-4 lg:ml-0">
            <h1
              className={clsx(
                'text-lg font-semibold',
                isDark ? 'text-slate-100' : 'text-gray-900',
              )}
            >
              {navItems.find(item => item.path === location.pathname)?.label || 'Dashboard'}
            </h1>
          </div>

          {/* Quick Actions + Theme Toggle */}
          <div className="flex items-center gap-2">
            <Link
              to="/csr/tickets/new"
              className="px-4 py-2 bg-fin1-primary text-white rounded-lg hover:bg-fin1-secondary transition-colors text-sm font-medium"
            >
              + Neues Ticket
            </Link>
            <button
              type="button"
              onClick={toggleTheme}
              className={clsx(
                'px-3 py-1 text-xs font-medium rounded-lg border',
                isDark
                  ? 'border-slate-500 text-slate-100 hover:bg-slate-600'
                  : 'border-gray-300 text-gray-700 hover:bg-gray-100',
              )}
            >
              {isDark ? 'Hell' : 'Dunkel'}
            </button>
          </div>
        </header>

        {/* Page Content */}
        <main
          data-content-area={isDark ? 'dark' : undefined}
          className={clsx(
            'p-4 lg:p-6 min-h-[calc(100vh-4rem)]',
            isDark ? 'bg-slate-800' : 'bg-gray-50',
          )}
        >
          {children}
        </main>
      </div>
    </div>
  );
}

// Navigation Icon Component for CSR
function CSRNavIcon({ name }: { name: string }) {
  const icons: Record<string, React.ReactNode> = {
    home: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
      </svg>
    ),
    ticket: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" />
      </svg>
    ),
    queue: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
      </svg>
    ),
    users: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
      </svg>
    ),
    'shield-check': (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
      </svg>
    ),
    'building-office': (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 21h18M3 10h18M10 21V10m4 11V10M6 7h12l-6-4-6 4zM6 10v11M18 10v11" />
      </svg>
    ),
    chart: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
      </svg>
    ),
    trend: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
      </svg>
    ),
    'document-text': (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
    ),
    'question-mark-circle': (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
  };

  return <>{icons[name] || icons.home}</>;
}
