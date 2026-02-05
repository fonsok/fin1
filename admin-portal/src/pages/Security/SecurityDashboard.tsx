import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { StatCard } from './components/StatCard';
import { OverviewTab } from './components/OverviewTab';
import { LoginsTab } from './components/LoginsTab';
import { SessionsTab } from './components/SessionsTab';
import { AlertsTab } from './components/AlertsTab';
import { mockStats, mockFailedLogins, mockSessions, mockAlerts } from './mockData';
import type { SecurityStats, FailedLogin, ActiveSession, SecurityAlert, TabType } from './types';

const TABS = [
  { id: 'overview' as const, label: 'Übersicht' },
  { id: 'logins' as const, label: 'Login-Historie' },
  { id: 'sessions' as const, label: 'Sessions' },
  { id: 'alerts' as const, label: 'Warnungen' },
];

export function SecurityDashboardPage(): JSX.Element {
  const [selectedTab, setSelectedTab] = useState<TabType>('overview');
  const queryClient = useQueryClient();

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
  });

  const { data: failedLogins } = useQuery({
    queryKey: ['failedLogins'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ logins: FailedLogin[] }>('getFailedLoginAttempts', {});
        return result.logins;
      } catch {
        return mockFailedLogins;
      }
    },
    initialData: mockFailedLogins,
    enabled: selectedTab === 'logins' || selectedTab === 'overview',
  });

  const { data: sessions } = useQuery({
    queryKey: ['activeSessions'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ sessions: ActiveSession[] }>('getActiveSessions', {});
        return result.sessions;
      } catch {
        return mockSessions;
      }
    },
    initialData: mockSessions,
    enabled: selectedTab === 'sessions' || selectedTab === 'overview',
  });

  const { data: alerts } = useQuery({
    queryKey: ['securityAlerts'],
    queryFn: async () => {
      try {
        const result = await cloudFunction<{ alerts: SecurityAlert[] }>('getSecurityAlerts', {});
        return result.alerts;
      } catch {
        return mockAlerts;
      }
    },
    initialData: mockAlerts,
  });

  const terminateSessionMutation = useMutation({
    mutationFn: (sessionId: string) => cloudFunction('terminateUserSession', { sessionId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['activeSessions'] });
    },
  });

  const unreviewedAlerts = alerts.filter((a) => !a.reviewed).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Sicherheit</h1>
        <p className="text-gray-500 mt-1">
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
      <div className="border-b border-gray-200">
        <nav className="flex gap-4">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setSelectedTab(tab.id)}
              className={`pb-3 px-1 text-sm font-medium border-b-2 transition-colors ${
                selectedTab === tab.id
                  ? 'border-fin1-primary text-fin1-primary'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
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
      {selectedTab === 'logins' && <LoginsTab failedLogins={failedLogins} />}
      {selectedTab === 'sessions' && (
        <SessionsTab
          sessions={sessions}
          onTerminate={(id) => terminateSessionMutation.mutate(id)}
          isTerminating={terminateSessionMutation.isPending}
        />
      )}
      {selectedTab === 'alerts' && <AlertsTab alerts={alerts} />}
    </div>
  );
}
