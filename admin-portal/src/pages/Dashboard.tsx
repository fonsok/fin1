import React from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { useAuth } from '../context/AuthContext';
import { usePermissions } from '../hooks/usePermissions';
import { useTheme } from '../context/ThemeContext';
import { getAdminDashboard } from '../api/admin';
import { Card, Badge } from '../components/ui';
import { formatNumber } from '../utils/format';

const mutedBody = (isDark: boolean) => (isDark ? 'text-slate-400' : 'text-gray-500');

export function DashboardPage() {
  const { user } = useAuth();
  const perms = usePermissions();
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const { data: stats, isLoading, error } = useQuery({
    queryKey: ['adminDashboard'],
    queryFn: getAdminDashboard,
    refetchInterval: 60000, // Refresh every minute
  });

  return (
    <div className="space-y-6">
      {/* Welcome Header */}
      <div className="bg-gradient-to-r from-fin1-primary to-fin1-secondary rounded-xl p-6 text-white">
        <h2 className="text-2xl font-bold">
          Willkommen, {user?.firstName || user?.email?.split('@')[0]}!
        </h2>
        <p className="text-white/80 mt-1">
          {perms.roleDescription} • Letzte Anmeldung: Heute
        </p>
      </div>

      {/* Stats Grid */}
      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <div
                className={clsx('h-4 rounded w-1/2 mb-2', isDark ? 'bg-slate-600' : 'bg-gray-200')}
              ></div>
              <div className={clsx('h-8 rounded w-1/3', isDark ? 'bg-slate-600' : 'bg-gray-200')}></div>
            </Card>
          ))}
        </div>
      ) : error ? (
        <Card className="text-center py-8">
          <p className={clsx(isDark ? 'text-red-400' : 'text-red-500')}>
            Fehler beim Laden der Statistiken
          </p>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* User Stats */}
          <StatCard
            title="Benutzer gesamt"
            value={formatNumber(stats?.users?.total || 0)}
            icon={
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            }
            color="blue"
          />

          <StatCard
            title="Aktive Benutzer"
            value={formatNumber(stats?.users?.active || 0)}
            icon={
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            }
            color="green"
          />

          <StatCard
            title="Ausstehend"
            value={formatNumber(stats?.users?.pending || 0)}
            icon={
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            }
            color="amber"
          />

          <StatCard
            title="Gesperrt"
            value={formatNumber(stats?.users?.suspended || 0)}
            icon={
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
              </svg>
            }
            color="red"
          />
        </div>
      )}

      {/* Role-specific sections */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Tickets: nicht für Voll-Admin (kein Ticket-Menü); u. a. Business Admin mit getTickets */}
        {perms.canViewTickets && user?.role !== 'admin' && (
          <Card>
            <div className="flex items-center justify-between mb-4">
              <h3 className={clsx('text-lg font-semibold', isDark ? 'text-slate-100' : 'text-gray-900')}>
                Offene Tickets
              </h3>
              <Badge variant="warning">{stats?.tickets?.open || 0}</Badge>
            </div>
            <div className="space-y-3">
              {stats?.tickets?.open === 0 ? (
                <p className={clsx('text-sm', mutedBody(isDark))}>Keine offenen Tickets</p>
              ) : (
                <p className={clsx('text-sm', mutedBody(isDark))}>
                  {stats?.tickets?.open} Tickets warten auf Bearbeitung
                </p>
              )}
              <Link
                to="/tickets"
                className="text-fin1-primary text-sm font-medium hover:underline"
              >
                Alle Tickets anzeigen →
              </Link>
            </div>
          </Card>
        )}

        {/* Compliance (for Compliance) */}
        {perms.canViewCompliance && (
          <Card>
            <div className="flex items-center justify-between mb-4">
              <h3 className={clsx('text-lg font-semibold', isDark ? 'text-slate-100' : 'text-gray-900')}>
                Compliance-Reviews
              </h3>
              <Badge variant="warning">{stats?.compliance?.pendingReviews || 0}</Badge>
            </div>
            <div className="space-y-3">
              {stats?.compliance?.pendingReviews === 0 ? (
                <p className={clsx('text-sm', mutedBody(isDark))}>Alle Events geprüft</p>
              ) : (
                <p className={clsx('text-sm', mutedBody(isDark))}>
                  {stats?.compliance?.pendingReviews} Events warten auf Review
                </p>
              )}
              <Link
                to="/compliance"
                className="text-fin1-primary text-sm font-medium hover:underline"
              >
                Compliance-Events anzeigen →
              </Link>
            </div>
          </Card>
        )}

        {/* 4-Eyes Approvals (for elevated roles) */}
        {perms.canApprove4Eyes && (
          <Card>
            <div className="flex items-center justify-between mb-4">
              <h3 className={clsx('text-lg font-semibold', isDark ? 'text-slate-100' : 'text-gray-900')}>
                4-Augen-Freigaben
              </h3>
              <Badge variant="info">{stats?.compliance?.pendingApprovals || 0}</Badge>
            </div>
            <div className="space-y-3">
              {stats?.compliance?.pendingApprovals === 0 ? (
                <p className={clsx('text-sm', mutedBody(isDark))}>Keine ausstehenden Freigaben</p>
              ) : (
                <p className={clsx('text-sm', mutedBody(isDark))}>
                  {stats?.compliance?.pendingApprovals} Anfragen warten auf Freigabe
                </p>
              )}
              <Link
                to="/approvals"
                className="text-fin1-primary text-sm font-medium hover:underline"
              >
                Freigaben anzeigen →
              </Link>
            </div>
          </Card>
        )}

        {/* Quick Actions */}
        <Card>
          <h3 className={clsx('text-lg font-semibold mb-4', isDark ? 'text-slate-100' : 'text-gray-900')}>
            Schnellzugriff
          </h3>
          <div className="grid grid-cols-2 gap-3">
            {perms.canViewUsers && (
              <QuickAction
                to="/users"
                icon={
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                }
                label="Benutzer suchen"
              />
            )}
            {perms.canViewAuditLogs && (
              <QuickAction
                to="/audit"
                icon={
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                }
                label="Audit-Logs"
              />
            )}
          </div>
        </Card>
      </div>
    </div>
  );
}

// Stat Card Component
function StatCard({
  title,
  value,
  icon,
  color,
}: {
  title: string;
  value: string;
  icon: React.ReactNode;
  color: 'blue' | 'green' | 'amber' | 'red';
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const colors = {
    blue: clsx(isDark ? 'bg-blue-900/40 text-blue-300' : 'bg-blue-50 text-blue-600'),
    green: clsx(isDark ? 'bg-green-900/40 text-green-300' : 'bg-green-50 text-green-600'),
    amber: clsx(isDark ? 'bg-amber-900/40 text-amber-300' : 'bg-amber-50 text-amber-600'),
    red: clsx(isDark ? 'bg-red-900/40 text-red-300' : 'bg-red-50 text-red-600'),
  };

  return (
    <Card>
      <div className="flex items-center gap-4">
        <div className={clsx('p-3 rounded-lg', colors[color])}>{icon}</div>
        <div>
          <p className={clsx('text-sm', mutedBody(isDark))}>{title}</p>
          <p className={clsx('text-2xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
            {value}
          </p>
        </div>
      </div>
    </Card>
  );
}

// Quick Action Component
function QuickAction({
  to,
  icon,
  label,
}: {
  to: string;
  icon: React.ReactNode;
  label: string;
}) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <Link
      to={to}
      className={clsx(
        'flex items-center gap-3 p-3 rounded-lg border transition-colors',
        isDark
          ? 'border-slate-600 hover:border-fin1-primary hover:bg-slate-600/40'
          : 'border-gray-200 hover:border-fin1-primary hover:bg-fin1-light/50',
      )}
    >
      <span className="text-fin1-primary">{icon}</span>
      <span className={clsx('text-sm font-medium', isDark ? 'text-slate-200' : 'text-gray-700')}>
        {label}
      </span>
    </Link>
  );
}
