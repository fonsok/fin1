import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge } from '../../components/ui';
import { formatDateTime } from '../../utils/format';
import type { SystemHealth, ServiceStatus } from './types';
import clsx from 'clsx';

function StatusBadge({ status }: { status: ServiceStatus['status'] }) {
  const variants: Record<string, 'success' | 'warning' | 'danger' | 'neutral'> = {
    healthy: 'success',
    degraded: 'warning',
    down: 'danger',
    unknown: 'neutral',
  };

  const labels: Record<string, string> = {
    healthy: 'Gesund',
    degraded: 'Beeinträchtigt',
    down: 'Ausgefallen',
    unknown: 'Unbekannt',
  };

  return <Badge variant={variants[status]}>{labels[status]}</Badge>;
}

function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);

  return parts.join(' ') || '< 1m';
}

export function SystemHealthPage() {
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ['systemHealth'],
    queryFn: () => cloudFunction<SystemHealth>('getSystemHealth'),
    refetchInterval: 30000,
  });

  const fallback: SystemHealth = {
    overall: isError ? 'down' : 'healthy',
    services: [],
    databases: [],
    serverTime: new Date().toISOString(),
    uptime: 0,
    version: '-',
  };

  const health = data || fallback;

  const overallStatusColor = {
    healthy: 'text-green-500',
    degraded: 'text-yellow-500',
    down: 'text-red-500',
  }[health.overall];

  const overallStatusBg = {
    healthy: 'bg-green-50 border-green-200',
    degraded: 'bg-yellow-50 border-yellow-200',
    down: 'bg-red-50 border-red-200',
  }[health.overall];

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold">System-Status</h2>
            <p className="text-sm text-gray-500 mt-1">
              Übersicht aller Services und Datenbanken
            </p>
          </div>
          <Button variant="secondary" onClick={() => refetch()} disabled={isLoading}>
            {isLoading ? 'Prüfe...' : 'Aktualisieren'}
          </Button>
        </div>
      </Card>

      {/* Overall Status */}
      <Card className={clsx('border', overallStatusBg)}>
        <div className="flex items-center gap-4">
          <div className={clsx('w-16 h-16 rounded-full flex items-center justify-center', overallStatusColor)}>
            {health.overall === 'healthy' ? (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            ) : health.overall === 'degraded' ? (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            ) : (
              <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            )}
          </div>
          <div>
            <h3 className="text-xl font-semibold">
              {health.overall === 'healthy' ? 'Alle Systeme betriebsbereit' :
               health.overall === 'degraded' ? 'Einige Systeme beeinträchtigt' :
               'Systemausfall erkannt'}
            </h3>
            <p className="text-sm text-gray-600 mt-1">
              Letzte Prüfung: {formatDateTime(health.serverTime)}
            </p>
          </div>
        </div>
      </Card>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <div className="text-center">
            <p className="text-sm text-gray-500">Uptime</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">{formatUptime(health.uptime)}</p>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <p className="text-sm text-gray-500">Version</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">v{health.version}</p>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <p className="text-sm text-gray-500">Services</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">
              {health.services.filter(s => s.status === 'healthy').length}/{health.services.length}
            </p>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <p className="text-sm text-gray-500">Node.js</p>
            <p className="text-2xl font-bold text-fin1-primary mt-1">{health.nodeVersion || '-'}</p>
          </div>
        </Card>
      </div>

      {/* Services */}
      <Card>
        <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
          <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
          </svg>
          Services
        </h3>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Service</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Antwortzeit</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Letzte Prüfung</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {health.services.map((service) => (
                <tr key={service.name} className="hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <span className="font-medium">{service.name}</span>
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={service.status} />
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {service.responseTime ? `${service.responseTime}ms` : '-'}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {formatDateTime(service.lastCheck)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {/* Databases */}
      <Card>
        <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
          <svg className="w-5 h-5 text-fin1-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
          </svg>
          Datenbanken
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {health.databases.map((db) => (
            <div
              key={db.name}
              className={clsx(
                'p-4 rounded-lg border',
                db.connected ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'
              )}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className={clsx(
                    'w-3 h-3 rounded-full',
                    db.connected ? 'bg-green-500' : 'bg-red-500'
                  )} />
                  <span className="font-medium">{db.name}</span>
                </div>
                <Badge variant={db.connected ? 'success' : 'danger'}>
                  {db.connected ? 'Verbunden' : 'Getrennt'}
                </Badge>
              </div>
              {db.version && (
                <p className="text-sm text-gray-600 mt-2">Version: {db.version}</p>
              )}
              {db.collections !== undefined && (
                <p className="text-sm text-gray-600">Collections: {db.collections}</p>
              )}
            </div>
          ))}
        </div>
      </Card>

      {/* Info */}
      <Card className="bg-gray-50 border-gray-200">
        <div className="flex gap-3">
          <svg className="w-5 h-5 text-gray-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div className="text-sm text-gray-600">
            <p>Die Statusabfrage erfolgt automatisch alle 30 Sekunden.</p>
            <p className="mt-1">Server-Zeit: {formatDateTime(health.serverTime)}</p>
          </div>
        </div>
      </Card>
    </div>
  );
}
