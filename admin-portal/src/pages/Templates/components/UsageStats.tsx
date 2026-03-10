import { Card } from '../../../components/ui/Card';
import type { TemplateUsageStats } from '../types';

interface UsageStatsProps {
  stats: TemplateUsageStats;
}

export function UsageStats({ stats }: UsageStatsProps) {
  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('de-DE', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  };

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="p-6">
          <div className="text-sm text-gray-500 mb-1">Zeitraum</div>
          <div className="text-2xl font-bold text-gray-900">{stats.period.days} Tage</div>
          <div className="text-sm text-gray-500 mt-1">
            {formatDate(stats.period.start)} - {formatDate(stats.period.end)}
          </div>
        </Card>

        <Card className="p-6">
          <div className="text-sm text-gray-500 mb-1">Gesamtverwendungen</div>
          <div className="text-3xl font-bold text-fin1-primary">{stats.totalUsage}</div>
          <div className="text-sm text-gray-500 mt-1">
            ∅ {Math.round(stats.totalUsage / stats.period.days)} pro Tag
          </div>
        </Card>

        <Card className="p-6">
          <div className="text-sm text-gray-500 mb-1">Aktive Agents</div>
          <div className="text-3xl font-bold text-gray-900">{stats.agentUsage.length}</div>
          <div className="text-sm text-gray-500 mt-1">haben Templates verwendet</div>
        </Card>
      </div>

      {/* Top Templates */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Templates</h3>

        {stats.topTemplates.length === 0 ? (
          <p className="text-gray-500 text-center py-8">
            Keine Daten im ausgewählten Zeitraum verfügbar.
          </p>
        ) : (
          <div className="space-y-3">
            {stats.topTemplates.map((template, index) => (
              <div
                key={template.id}
                className="flex items-center gap-4 p-3 bg-gray-50 rounded-lg"
              >
                <div className="text-2xl font-bold text-gray-300 w-8 text-center">
                  {index + 1}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-gray-900 truncate">{template.title}</div>
                  <div className="text-sm text-gray-500">{template.category}</div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-fin1-primary">{template.usageCount}</div>
                  <div className="text-xs text-gray-500">Verwendungen</div>
                </div>
                <div className="w-24">
                  <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-fin1-primary rounded-full"
                      style={{
                        width: `${Math.round(
                          (template.usageCount / stats.topTemplates[0].usageCount) * 100
                        )}%`,
                      }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* Agent Usage */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Nutzung nach Agent</h3>

        {stats.agentUsage.length === 0 ? (
          <p className="text-gray-500 text-center py-8">
            Keine Daten im ausgewählten Zeitraum verfügbar.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 text-sm font-medium text-gray-500">Agent ID</th>
                  <th className="text-right py-2 text-sm font-medium text-gray-500">
                    Verwendungen
                  </th>
                  <th className="text-right py-2 text-sm font-medium text-gray-500">
                    % der Gesamtnutzung
                  </th>
                </tr>
              </thead>
              <tbody>
                {stats.agentUsage.map((agent) => (
                  <tr key={agent.agentId} className="border-b border-gray-100 last:border-0">
                    <td className="py-3 font-mono text-sm">{agent.agentId}</td>
                    <td className="py-3 text-right font-medium">{agent.usageCount}</td>
                    <td className="py-3 text-right text-gray-500">
                      {((agent.usageCount / stats.totalUsage) * 100).toFixed(1)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}
