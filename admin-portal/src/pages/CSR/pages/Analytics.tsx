import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { getTicketMetrics, getAgentMetrics, getAvailableAgents } from '../api';

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
        <h1 className="text-2xl font-bold">Analytics Dashboard</h1>
        <div className="flex gap-2">
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value as 'week' | 'month' | 'quarter')}
            className="px-4 py-2 border rounded-lg"
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
              <div className="text-3xl font-bold text-gray-900">{metrics.totalTickets}</div>
              <div className="text-sm text-gray-500 mt-1">Gesamt Tickets</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-3xl font-bold text-orange-600">{metrics.openTickets}</div>
              <div className="text-sm text-gray-500 mt-1">Offene Tickets</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-3xl font-bold text-green-600">{metrics.resolvedTickets}</div>
              <div className="text-sm text-gray-500 mt-1">Gelöste Tickets</div>
            </div>
          </Card>
          <Card>
            <div className="text-center">
              <div className="text-3xl font-bold text-blue-600">
                {Math.round(metrics.averageResolutionTime / 60)}h
              </div>
              <div className="text-sm text-gray-500 mt-1">Ø Lösungszeit</div>
            </div>
          </Card>
        </div>
      )}

      {/* Agent Performance */}
      <Card>
        <h2 className="text-lg font-semibold mb-4">Agent-Performance</h2>
        <div className="mb-4">
          <select
            value={selectedAgentId}
            onChange={(e) => setSelectedAgentId(e.target.value)}
            className="px-4 py-2 border rounded-lg"
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
                    <td
                      className={clsx(
                        'px-6 py-4 text-sm',
                        isDark ? 'text-slate-300' : 'text-gray-600',
                      )}
                    >
                      {row.label}
                    </td>
                    <td
                      className={clsx(
                        'px-6 py-4 text-base font-semibold tabular-nums',
                        isDark ? 'text-slate-100' : 'text-gray-900',
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
          <p className="text-gray-500 text-center py-4">Wählen Sie einen Agenten aus, um Details anzuzeigen</p>
        )}
      </Card>
    </div>
  );
}
