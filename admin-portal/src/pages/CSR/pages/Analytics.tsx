import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card } from '../../../components/ui';
import { getTicketMetrics, getAgentMetrics, getAvailableAgents } from '../api';

export function AnalyticsPage() {
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

        {agentMetrics && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <div className="text-sm text-gray-500">Zugewiesene Tickets</div>
              <div className="text-2xl font-bold">{agentMetrics.ticketsAssigned}</div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Gelöste Tickets</div>
              <div className="text-2xl font-bold">{agentMetrics.ticketsResolved}</div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Ø Lösungszeit</div>
              <div className="text-2xl font-bold">
                {Math.round(agentMetrics.averageResolutionTime / 60)}h
              </div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Kundenzufriedenheit</div>
              <div className="text-2xl font-bold">{agentMetrics.customerSatisfaction.toFixed(1)}/5</div>
            </div>
          </div>
        )}

        {!selectedAgentId && (
          <p className="text-gray-500 text-center py-4">Wählen Sie einen Agenten aus, um Details anzuzeigen</p>
        )}
      </Card>
    </div>
  );
}
