import { useCallback, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction } from '../../api/admin';
import { nextSortState, type SortOrder } from '../../components/table/SortableTh';
import { PaginationBar } from '../../components/ui';
import { StatCard } from './components/StatCard';
import { OverviewTab } from './components/OverviewTab';
import { LoginsTab } from './components/LoginsTab';
import { SessionsTab } from './components/SessionsTab';
import { AlertsTab } from './components/AlertsTab';
import { useTheme } from '../../context/ThemeContext';
import { mockStats, mockFailedLogins, mockSessions, mockAlerts } from './mockData';
import type { SecurityStats, FailedLogin, ActiveSession, SecurityAlert, TabType } from './types';

import { adminBorderChrome, adminControlField, adminMuted, adminPrimary } from '../../utils/adminThemeClasses';
const TABS = [
  { id: 'overview' as const, label: 'Übersicht' },
  { id: 'logins' as const, label: 'Login-Historie' },
  { id: 'sessions' as const, label: 'Sessions' },
  { id: 'alerts' as const, label: 'Warnungen' },
];

export function SecurityDashboardPage(): JSX.Element {
  const [selectedTab, setSelectedTab] = useState<TabType>('overview');
  const [loginsPage, setLoginsPage] = useState(0);
  const [sessionsPage, setSessionsPage] = useState(0);
  const [alertsPage, setAlertsPage] = useState(0);
  const [loginsPageSize, setLoginsPageSize] = useState(50);
  const [sessionsPageSize, setSessionsPageSize] = useState(50);
  const [alertsPageSize, setAlertsPageSize] = useState(50);
  const [loginsSortBy, setLoginsSortBy] = useState('createdAt');
  const [loginsSortOrder, setLoginsSortOrder] = useState<SortOrder>('desc');
  const [sessionsSortBy, setSessionsSortBy] = useState('createdAt');
  const [sessionsSortOrder, setSessionsSortOrder] = useState<SortOrder>('desc');
  const [alertsSortBy, setAlertsSortBy] = useState('occurredAt');
  const [alertsSortOrder, setAlertsSortOrder] = useState<SortOrder>('desc');
  const queryClient = useQueryClient();
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const onLoginsSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, loginsSortBy, loginsSortOrder);
      setLoginsSortBy(next.sortBy);
      setLoginsSortOrder(next.sortOrder);
      setLoginsPage(0);
    },
    [loginsSortBy, loginsSortOrder],
  );

  const onSessionsSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, sessionsSortBy, sessionsSortOrder);
      setSessionsSortBy(next.sortBy);
      setSessionsSortOrder(next.sortOrder);
      setSessionsPage(0);
    },
    [sessionsSortBy, sessionsSortOrder],
  );

  const onAlertsSort = useCallback(
    (field: string) => {
      const next = nextSortState(field, alertsSortBy, alertsSortOrder);
      setAlertsSortBy(next.sortBy);
      setAlertsSortOrder(next.sortOrder);
      setAlertsPage(0);
    },
    [alertsSortBy, alertsSortOrder],
  );

  const { data: stats } = useQuery({
    queryKey: ['securityDashboard'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ stats: SecurityStats }>('getSecurityDashboardStats', {});
        return result.stats;
      } catch {
        return mockStats;
      }
    },
    initialData: mockStats,
    initialDataUpdatedAt: 0,
    staleTime: 30_000,
  });

  const { data: failedLoginsData } = useQuery({
    queryKey: ['failedLogins', loginsPage, loginsPageSize, loginsSortBy, loginsSortOrder],
    queryFn: async () => {
      try {
        return await cloudFunction<{ logins: FailedLogin[]; total: number }>('getFailedLoginAttempts', {
          limit: loginsPageSize,
          skip: loginsPage * loginsPageSize,
          sortBy: loginsSortBy,
          sortOrder: loginsSortOrder,
        });
      } catch {
        return { logins: mockFailedLogins, total: mockFailedLogins.length };
      }
    },
    initialData: { logins: mockFailedLogins, total: mockFailedLogins.length },
    initialDataUpdatedAt: 0,
    staleTime: 30_000,
    enabled: selectedTab === 'logins' || selectedTab === 'overview',
  });

  const { data: sessionsData } = useQuery({
    queryKey: ['activeSessions', sessionsPage, sessionsPageSize, sessionsSortBy, sessionsSortOrder],
    queryFn: async () => {
      try {
        return await cloudFunction<{ sessions: ActiveSession[]; total: number }>('getActiveSessions', {
          limit: sessionsPageSize,
          skip: sessionsPage * sessionsPageSize,
          sortBy: sessionsSortBy,
          sortOrder: sessionsSortOrder,
        });
      } catch {
        return { sessions: mockSessions, total: mockSessions.length };
      }
    },
    initialData: { sessions: mockSessions, total: mockSessions.length },
    initialDataUpdatedAt: 0,
    staleTime: 30_000,
    enabled: selectedTab === 'sessions' || selectedTab === 'overview',
  });

  const { data: alertsData } = useQuery({
    queryKey: ['securityAlerts', alertsPage, alertsPageSize, alertsSortBy, alertsSortOrder],
    queryFn: async () => {
      try {
        return await cloudFunction<{ alerts: SecurityAlert[]; total: number }>('getSecurityAlerts', {
          limit: alertsPageSize,
          skip: alertsPage * alertsPageSize,
          sortBy: alertsSortBy,
          sortOrder: alertsSortOrder,
        });
      } catch {
        return { alerts: mockAlerts, total: mockAlerts.length };
      }
    },
    initialData: { alerts: mockAlerts, total: mockAlerts.length },
    initialDataUpdatedAt: 0,
    staleTime: 30_000,
    enabled: selectedTab === 'alerts' || selectedTab === 'overview',
  });

  const terminateSessionMutation = useMutation({
    mutationFn: (sessionId: string) => cloudFunction('terminateUserSession', { sessionId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['activeSessions'] });
    },
  });

  const failedLogins = failedLoginsData?.logins ?? [];
  const failedLoginsTotal = failedLoginsData?.total ?? 0;
  const sessions = sessionsData?.sessions ?? [];
  const sessionsTotal = sessionsData?.total ?? 0;
  const alerts = alertsData?.alerts ?? [];
  const alertsTotal = alertsData?.total ?? 0;
  const unreviewedAlerts = alerts.filter((a) => !a.reviewed).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Sicherheit</h1>
        <p className={clsx('mt-1', adminMuted(isDark))}>
          Überwachung von Login-Aktivitäten, Sessions und Sicherheitswarnungen
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard
          title="Fehlgeschlagene Logins"
          value={stats.failedLoginsToday.toString()}
          subtitle="Heute"
          variant={stats.failedLoginsToday > 10 ? 'warning' : 'default'}
        />
        <StatCard
          title="Fehlgeschlagene Logins"
          value={stats.failedLoginsWeek.toString()}
          subtitle="Diese Woche"
          variant="default"
        />
        <StatCard
          title="Gesperrte Konten"
          value={stats.lockedAccounts.toString()}
          subtitle="Aktuell"
          variant={stats.lockedAccounts > 0 ? 'error' : 'default'}
        />
        <StatCard
          title="Aktive Sessions"
          value={stats.activeSessions.toString()}
          subtitle="Gerade online"
          variant="success"
        />
        <StatCard
          title="Sicherheitswarnungen"
          value={stats.suspiciousActivities.toString()}
          subtitle="Ungeprüft"
          variant={stats.suspiciousActivities > 0 ? 'error' : 'default'}
        />
      </div>

      {/* Tabs */}
      <div className={clsx('border-b', adminBorderChrome(isDark))}>
        <nav className="flex gap-4">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setSelectedTab(tab.id)}
              className={clsx('pb-3 px-1 text-sm font-medium border-b-2 transition-colors', {
                'border-fin1-primary text-fin1-primary': selectedTab === tab.id,
                'border-transparent text-slate-400 hover:text-slate-200': selectedTab !== tab.id && isDark,
                'border-transparent text-gray-500 hover:text-gray-700': selectedTab !== tab.id && !isDark,
              })}
            >
              {tab.label}
              {tab.id === 'alerts' && unreviewedAlerts > 0 && (
                <span className="ml-2 bg-red-500 text-white text-xs px-1.5 py-0.5 rounded-full">
                  {unreviewedAlerts}
                </span>
              )}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {selectedTab === 'overview' && <OverviewTab failedLogins={failedLogins} alerts={alerts} />}
      {selectedTab === 'logins' && (
        <>
          <div className="flex justify-end">
            <select
              value={loginsPageSize}
              onChange={(e) => { setLoginsPageSize(Number(e.target.value)); setLoginsPage(0); }}
              className={clsx(
                'px-3 py-1.5 text-sm border rounded-lg',
                adminControlField(isDark),
              )}
            >
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
              <option value={250}>250 / Seite</option>
            </select>
          </div>
          <LoginsTab
            failedLogins={failedLogins}
            sortBy={loginsSortBy}
            sortOrder={loginsSortOrder}
            onSort={onLoginsSort}
          />
          <PaginationBar
            page={loginsPage}
            pageSize={loginsPageSize}
            total={failedLoginsTotal}
            itemLabel="Einträgen"
            isDark={isDark}
            onPageChange={setLoginsPage}
          />
        </>
      )}
      {selectedTab === 'sessions' && (
        <>
          <div className="flex justify-end">
            <select
              value={sessionsPageSize}
              onChange={(e) => { setSessionsPageSize(Number(e.target.value)); setSessionsPage(0); }}
              className={clsx(
                'px-3 py-1.5 text-sm border rounded-lg',
                adminControlField(isDark),
              )}
            >
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
              <option value={250}>250 / Seite</option>
            </select>
          </div>
          <SessionsTab
            sessions={sessions}
            onTerminate={(id) => terminateSessionMutation.mutate(id)}
            isTerminating={terminateSessionMutation.isPending}
            sortBy={sessionsSortBy}
            sortOrder={sessionsSortOrder}
            onSort={onSessionsSort}
          />
          <PaginationBar
            page={sessionsPage}
            pageSize={sessionsPageSize}
            total={sessionsTotal}
            itemLabel="Sessions"
            isDark={isDark}
            onPageChange={setSessionsPage}
          />
        </>
      )}
      {selectedTab === 'alerts' && (
        <>
          <div className="flex justify-end">
            <select
              value={alertsPageSize}
              onChange={(e) => { setAlertsPageSize(Number(e.target.value)); setAlertsPage(0); }}
              className={clsx(
                'px-3 py-1.5 text-sm border rounded-lg',
                adminControlField(isDark),
              )}
            >
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
              <option value={250}>250 / Seite</option>
            </select>
          </div>
          <AlertsTab
            alerts={alerts}
            sortBy={alertsSortBy}
            sortOrder={alertsSortOrder}
            onSort={onAlertsSort}
            isDark={isDark}
          />
          <PaginationBar
            page={alertsPage}
            pageSize={alertsPageSize}
            total={alertsTotal}
            itemLabel="Warnungen"
            isDark={isDark}
            onPageChange={setAlertsPage}
          />
        </>
      )}
    </div>
  );
}
