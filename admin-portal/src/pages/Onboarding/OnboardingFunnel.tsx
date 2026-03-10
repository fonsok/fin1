import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/parse';
import { Card, Badge } from '../../components/ui';

interface FunnelStep {
  step: string;
  count: number;
  dropOffPercent: number;
}

interface StuckUser {
  userId: string;
  email: string;
  lastStep: string;
  lastActivity: string;
  createdAt: string;
  emailVerified: boolean;
}

interface FunnelData {
  period: { days: number; since: string };
  summary: {
    totalStarted: number;
    totalCompleted: number;
    totalEmailVerified: number;
    completionRate: number;
    avgCompletionMinutes: number | null;
  };
  funnel: FunnelStep[];
  stuckUsers: StuckUser[];
}

const STEP_LABELS: Record<string, string> = {
  emailVerification: 'E-Mail Verifizierung',
  personal: 'Persönliche Daten',
  address: 'Adresse & Steuer',
  tax: 'Steuer-ID',
  verification: 'Identifikation',
  experience: 'Anlageerfahrung',
  risk: 'Risikoprofil',
  consents: 'Zustimmungen',
};

export function OnboardingFunnelPage() {
  const [days, setDays] = React.useState(30);

  const { data, isLoading, error } = useQuery<FunnelData>({
    queryKey: ['onboardingFunnel', days],
    queryFn: () => cloudFunction<FunnelData>('getOnboardingFunnel', { days }),
    refetchInterval: 120000,
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Onboarding-Funnel</h1>
          <p className="text-gray-500 mt-1">Registrierungsfortschritt und Abbruchraten</p>
        </div>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value={7}>Letzte 7 Tage</option>
          <option value={30}>Letzte 30 Tage</option>
          <option value={90}>Letzte 90 Tage</option>
        </select>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <div className="h-4 bg-gray-200 rounded w-1/2 mb-2" />
              <div className="h-8 bg-gray-200 rounded w-1/3" />
            </Card>
          ))}
        </div>
      ) : error ? (
        <Card className="text-center py-8">
          <p className="text-red-500">Fehler beim Laden der Funnel-Daten</p>
        </Card>
      ) : data ? (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <SummaryCard
              title="Gestartet"
              value={data.summary.totalStarted}
              color="blue"
            />
            <SummaryCard
              title="E-Mail verifiziert"
              value={data.summary.totalEmailVerified}
              color="cyan"
            />
            <SummaryCard
              title="Abgeschlossen"
              value={data.summary.totalCompleted}
              subtitle={`${data.summary.completionRate}% Conversion`}
              color="green"
            />
            <SummaryCard
              title="Ø Dauer"
              value={data.summary.avgCompletionMinutes != null ? `${data.summary.avgCompletionMinutes} min` : '–'}
              color="purple"
            />
          </div>

          {/* Funnel Visualization */}
          <Card>
            <div className="p-5">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Funnel nach Schritt</h2>
              <div className="space-y-3">
                {data.funnel.map((step, idx) => {
                  const maxCount = Math.max(data.summary.totalStarted, 1);
                  const widthPct = Math.max((step.count / maxCount) * 100, 2);
                  const isHighDropOff = step.dropOffPercent > 30;
                  return (
                    <div key={step.step} className="flex items-center gap-4">
                      <div className="w-40 text-sm text-gray-600 text-right flex-shrink-0">
                        {STEP_LABELS[step.step] || step.step}
                      </div>
                      <div className="flex-1 relative">
                        <div className="h-8 bg-gray-100 rounded-lg overflow-hidden">
                          <div
                            className="h-full bg-gradient-to-r from-fin1-primary to-fin1-secondary rounded-lg transition-all duration-500"
                            style={{ width: `${widthPct}%` }}
                          />
                        </div>
                      </div>
                      <div className="w-16 text-right text-sm font-semibold text-gray-800 flex-shrink-0">
                        {step.count}
                      </div>
                      <div className={`w-16 text-right text-xs flex-shrink-0 ${isHighDropOff ? 'text-red-600 font-semibold' : 'text-gray-400'}`}>
                        {idx > 0 ? `−${step.dropOffPercent}%` : ''}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </Card>

          {/* Stuck Users */}
          {data.stuckUsers.length > 0 && (
            <Card>
              <div className="p-5">
                <h2 className="text-lg font-semibold text-gray-900 mb-1">Feststeckende Benutzer</h2>
                <p className="text-sm text-gray-500 mb-4">Keine Aktivität seit &gt;24h, Onboarding nicht abgeschlossen</p>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-gray-200">
                        <th className="text-left py-2 px-3 font-medium text-gray-500">E-Mail</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-500">Letzter Schritt</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-500">E-Mail bestätigt</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-500">Letzte Aktivität</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-500">Registriert</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.stuckUsers.map((u) => (
                        <tr key={u.userId} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="py-2 px-3 font-medium text-gray-800">{u.email}</td>
                          <td className="py-2 px-3">
                            <Badge variant="info">
                              {STEP_LABELS[u.lastStep] || u.lastStep}
                            </Badge>
                          </td>
                          <td className="py-2 px-3">
                            {u.emailVerified ? (
                              <Badge variant="success">Ja</Badge>
                            ) : (
                              <Badge variant="warning">Nein</Badge>
                            )}
                          </td>
                          <td className="py-2 px-3 text-gray-500">{formatRelative(u.lastActivity)}</td>
                          <td className="py-2 px-3 text-gray-500">{formatRelative(u.createdAt)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </Card>
          )}
        </>
      ) : null}
    </div>
  );
}

function SummaryCard({ title, value, subtitle, color }: {
  title: string;
  value: string | number;
  subtitle?: string;
  color: string;
}) {
  const colorMap: Record<string, string> = {
    blue: 'bg-blue-50 text-blue-700',
    green: 'bg-green-50 text-green-700',
    cyan: 'bg-cyan-50 text-cyan-700',
    purple: 'bg-purple-50 text-purple-700',
  };
  return (
    <Card>
      <div className="p-5">
        <p className="text-sm text-gray-500">{title}</p>
        <p className={`text-2xl font-bold mt-1 ${colorMap[color]?.split(' ')[1] || 'text-gray-900'}`}>
          {value}
        </p>
        {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
      </div>
    </Card>
  );
}

function formatRelative(dateStr: string): string {
  const d = new Date(dateStr);
  const now = Date.now();
  const diffMs = now - d.getTime();
  const diffH = Math.floor(diffMs / 3600000);
  if (diffH < 1) return 'vor wenigen Minuten';
  if (diffH < 24) return `vor ${diffH}h`;
  const diffD = Math.floor(diffH / 24);
  if (diffD === 1) return 'gestern';
  if (diffD < 7) return `vor ${diffD} Tagen`;
  return d.toLocaleDateString('de-DE');
}
