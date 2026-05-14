import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableBodyCellMutedClasses,
  tableBodyCellPrimaryClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { getTicketMetrics, getAgentMetrics, getAvailableAgents } from '../api';

import { adminControlField, adminPrimary } from '../../../utils/adminThemeClasses';
export function AnalyticsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [dateRange, setDateRange] = useState<'week' | 'month' | 'quarter'>('week');
  const [selectedAgentId, setSelectedAgentId] = useState<string>('');

  const getDateRange = () => {
    const now = new Date();
    let start: Date;
    switch (dateRange) {
      case 'week':
        start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      case 'quarter':
        start = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
        break;
    }
    return { start, end: now };
  };

  const { start, end } = getDateRange();

  const { data: metrics } = useQuery({
    queryKey: ['csr-metrics', dateRange],
    queryFn: () => getTicketMetrics(start, end),
  });

  const { data: agents } = useQuery({
    queryKey: ['csr-agents'],
    queryFn: () => getAvailableAgents(),
  });

  const { data: agentMetrics } = useQuery({
    queryKey: ['agent-metrics', selectedAgentId, dateRange],
    queryFn: () => getAgentMetrics(selectedAgentId, start, end),
    enabled: !!selectedAgentId,
  });

  const agentPerformanceRows = useMemo(() => {
    if (!agentMetrics) return [];
    return [
      { label: 'Zugewiesene Tickets', value: String(agentMetrics.ticketsAssigned) },
      { label: 'Gelöste Tickets', value: String(agentMetrics.ticketsResolved) },
      {
        label: 'Ø Lösungszeit',
        value: `${Math.round(agentMetrics.averageResolutionTime / 60)}h`,
      },
      {
        label: 'Kundenzufriedenheit',
        value: `${agentMetrics.customerSatisfaction.toFixed(1)}/5`,
      },
    ];
  }, [agentMetrics]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>
          Analytics Dashboard
        </h1>
        <div className="flex gap-2">
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value as 'week' | 'month' | 'quarter')}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              adminControlField(isDark),
            )}
          >
            <option value="week">Letzte Woche</option>
            <option value="month">Letzter Monat</option>
            <option value="quarter">Letztes Quartal</option>
          </select>
        </div>
      </div>

      {/* Overall Metrics */}
      {metrics && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <div className="text-center">
              <div className={clsx('text-3xl font-bold', tableBodyCellPrimaryClasses(isDark))}>
                {metrics.totalTickets}
              </div>
              <div className={clsx('text-sm mt-1', tableBodyCellMutedClasses(isDark))}>Gesamt Tickets</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-3xl font-bold text-orange-600">{metrics.openTickets}</div>
              <div className={clsx('text-sm mt-1', tableBodyCellMutedClasses(isDark))}>Offene Tickets</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-3xl font-bold text-green-600">{metrics.resolvedTickets}</div>
              <div className={clsx('text-sm mt-1', tableBodyCellMutedClasses(isDark))}>Gelöste Tickets</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-3xl font-bold text-blue-600">
                {Math.round(metrics.averageResolutionTime / 60)}h
              </div>
              <div className={clsx('text-sm mt-1', tableBodyCellMutedClasses(isDark))}>Ø Lösungszeit</div>
            </div>
          </Card>
        </div>
      )}

      {/* Agent Performance */}
      <Card>
        <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>
          Agent-Performance
        </h2>
        <div className="mb-4">
          <select
            value={selectedAgentId}
            onChange={(e) => setSelectedAgentId(e.target.value)}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
              adminControlField(isDark),
            )}
          >
            <option value="">Agent auswählen...</option>
            {agents?.map((agent) => (
              <option key={agent.objectId} value={agent.objectId}>
                {agent.firstName} {agent.lastName} ({agent.email})
              </option>
            ))}
          </select>
        </div>

        {agentMetrics && agentPerformanceRows.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className={tableTheadSurfaceClasses(isDark)}>
                <tr>
                  <th
                    className={clsx(
                      'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                      tableHeaderCellTextClasses(isDark),
                    )}
                  >
                    Kennzahl
                  </th>
                  <th
                    className={clsx(
                      'px-6 py-3 text-left text-xs font-medium uppercase tracking-wider',
                      tableHeaderCellTextClasses(isDark),
                    )}
                  >
                    Wert
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {agentPerformanceRows.map((row, index) => (
                  <tr key={row.label} className={listRowStripeClasses(isDark, index)}>
                    <td className={clsx('px-6 py-4 text-sm', tableBodyCellMutedClasses(isDark))}>{row.label}</td>
                    <td
                      className={clsx(
                        'px-6 py-4 text-base font-semibold tabular-nums',
                        tableBodyCellPrimaryClasses(isDark),
                      )}
                    >
                      {row.value}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!selectedAgentId && (
          <p className={clsx('text-center py-4 text-sm', tableBodyCellMutedClasses(isDark))}>
            Wählen Sie einen Agenten aus, um Details anzuzeigen
          </p>
        )}
      </Card>
    </div>
  );
}
