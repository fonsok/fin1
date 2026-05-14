import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { cloudFunction } from '../../api/parse';
import { Card, Badge } from '../../components/ui';
import { useTheme } from '../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../utils/tableStriping';
import clsx from 'clsx';

import { adminCaption, adminHeadline, adminMuted, adminPrimary, adminSoft } from '../../utils/adminThemeClasses';
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
  const { theme } = useTheme();
  const isDark = theme === 'dark';

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
          <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>Onboarding-Funnel</h1>
          <p className={clsx('mt-1', adminMuted(isDark))}>
            Registrierungsfortschritt und Abbruchraten
          </p>
        </div>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          className={clsx(
            'px-3 py-2 border rounded-lg text-sm',
            isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
          )}
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
              <div className={clsx('h-4 rounded w-1/2 mb-2', isDark ? 'bg-slate-600' : 'bg-gray-200')} />
              <div className={clsx('h-8 rounded w-1/3', isDark ? 'bg-slate-600' : 'bg-gray-200')} />
            </Card>
          ))}
        </div>
      ) : error ? (
        <Card className="text-center py-8">
          <p className={clsx(isDark ? 'text-red-400' : 'text-red-500')}>Fehler beim Laden der Funnel-Daten</p>
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
              <h2 className={clsx('text-lg font-semibold mb-4', adminPrimary(isDark))}>
                Funnel nach Schritt
              </h2>
              <div className="space-y-3">
                {data.funnel.map((step, idx) => {
                  const maxCount = Math.max(data.summary.totalStarted, 1);
                  const widthPct = Math.max((step.count / maxCount) * 100, 2);
                  const isHighDropOff = step.dropOffPercent > 30;
                  return (
                    <div key={step.step} className="flex items-center gap-4">
                      <div
                        className={clsx(
                          'w-40 text-sm text-right flex-shrink-0',
                          adminSoft(isDark),
                        )}
                      >
                        {STEP_LABELS[step.step] || step.step}
                      </div>
                      <div className="flex-1 relative">
                        <div className={clsx('h-8 rounded-lg overflow-hidden', isDark ? 'bg-slate-900/60' : 'bg-gray-100')}>
                          <div
                            className="h-full bg-gradient-to-r from-fin1-primary to-fin1-secondary rounded-lg transition-all duration-500"
                            style={{ width: `${widthPct}%` }}
                          />
                        </div>
                      </div>
                      <div
                        className={clsx(
                          'w-16 text-right text-sm font-semibold flex-shrink-0',
                          adminHeadline(isDark),
                        )}
                      >
                        {step.count}
                      </div>
                      <div
                        className={clsx(
                          'w-16 text-right text-xs flex-shrink-0',
                          isHighDropOff
                            ? 'text-red-600 font-semibold'
                            : isDark
                              ? 'text-slate-500'
                              : 'text-gray-400',
                        )}
                      >
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
                <h2 className={clsx('text-lg font-semibold mb-1', adminPrimary(isDark))}>
                  Feststeckende Benutzer
                </h2>
                <p className={clsx('text-sm mb-4', adminMuted(isDark))}>
                  Keine Aktivität seit &gt;24h, Onboarding nicht abgeschlossen
                </p>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className={tableTheadSurfaceClasses(isDark)}>
                      <tr>
                        {(['E-Mail', 'Letzter Schritt', 'E-Mail bestätigt', 'Letzte Aktivität', 'Registriert'] as const).map(
                          (label) => (
                            <th
                              key={label}
                              className={clsx(
                                'text-left py-3 px-4 text-xs font-medium uppercase',
                                tableHeaderCellTextClasses(isDark),
                              )}
                            >
                              {label}
                            </th>
                          ),
                        )}
                      </tr>
                    </thead>
                    <tbody className={tableBodyDivideClasses(isDark)}>
                      {data.stuckUsers.map((u, index) => (
                        <tr key={u.userId} className={listRowStripeClasses(isDark, index)}>
                          <td className={clsx('py-3 px-4 font-medium', adminHeadline(isDark))}>
                            {u.email}
                          </td>
                          <td className="py-3 px-4">
                            <Badge variant="info">{STEP_LABELS[u.lastStep] || u.lastStep}</Badge>
                          </td>
                          <td className="py-3 px-4">
                            {u.emailVerified ? (
                              <Badge variant="success">Ja</Badge>
                            ) : (
                              <Badge variant="warning">Nein</Badge>
                            )}
                          </td>
                          <td className={clsx('py-3 px-4', adminMuted(isDark))}>
                            {formatRelative(u.lastActivity)}
                          </td>
                          <td className={clsx('py-3 px-4', adminMuted(isDark))}>
                            {formatRelative(u.createdAt)}
                          </td>
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
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const valueTone: Record<string, string> = {
    blue: isDark ? 'text-blue-300' : 'text-blue-700',
    green: isDark ? 'text-green-300' : 'text-green-700',
    cyan: isDark ? 'text-cyan-300' : 'text-cyan-700',
    purple: isDark ? 'text-purple-300' : 'text-purple-700',
  };

  return (
    <Card>
      <div className="p-5">
        <p className={clsx('text-sm', adminMuted(isDark))}>{title}</p>
        <p className={clsx('text-2xl font-bold mt-1', valueTone[color] ?? (adminPrimary(isDark)))}>
          {value}
        </p>
        {subtitle && (
          <p className={clsx('text-xs mt-1', adminCaption(isDark))}>{subtitle}</p>
        )}
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
