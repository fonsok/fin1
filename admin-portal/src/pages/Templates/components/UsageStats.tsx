import { useMemo, useState } from 'react';
import clsx from 'clsx';
import { useQuery } from '@tanstack/react-query';
import { Card } from '../../../components/ui/Card';
import { Button } from '../../../components/ui/Button';
import { useTheme } from '../../../context/ThemeContext';
import {
  listRowStripeClasses,
  tableBodyDivideClasses,
  tableHeaderCellTextClasses,
  tableTheadSurfaceClasses,
} from '../../../utils/tableStriping';
import { getTemplateUsageStats, type GetTemplateUsageStatsParams } from '../api';
import type { TemplateUsageStats } from '../types';

function toInputDateLocal(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseLocalDateStart(ymd: string): Date {
  const [y, m, d] = ymd.split('-').map((x) => parseInt(x, 10));
  return new Date(y, m - 1, d, 0, 0, 0, 0);
}

function parseLocalDateEnd(ymd: string): Date {
  const [y, m, d] = ymd.split('-').map((x) => parseInt(x, 10));
  return new Date(y, m - 1, d, 23, 59, 59, 999);
}

const MAX_RANGE_MS = 366 * 24 * 60 * 60 * 1000;

type Picker = 'd7' | 'd30' | 'd90' | 'custom';

function defaultLast30(): { from: string; to: string } {
  const t = new Date();
  const s = new Date();
  s.setDate(s.getDate() - 30);
  return { from: toInputDateLocal(s), to: toInputDateLocal(t) };
}

function UsageStatsContent({ stats }: { stats: TemplateUsageStats }) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('de-DE', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  };

  const muted = isDark ? 'text-slate-400' : 'text-gray-500';
  const heading = isDark ? 'text-slate-100' : 'text-gray-900';
  const maxTopUsage = stats.topTemplates[0]?.usageCount ?? 0;
  const daysForAvg = Math.max(1, stats.period.days);
  const avgPerDay = Math.round(stats.totalUsage / daysForAvg);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="p-6">
          <div className={clsx('text-sm mb-1', muted)}>Zeitraum</div>
          <div className={clsx('text-2xl font-bold', heading)}>{stats.period.days} Tage</div>
          <div className={clsx('text-sm mt-1', muted)}>
            {formatDate(stats.period.start)} – {formatDate(stats.period.end)}
          </div>
        </Card>

        <Card className="p-6">
          <div className={clsx('text-sm mb-1', muted)}>Gesamtverwendungen</div>
          <div className="text-3xl font-bold text-fin1-primary">{stats.totalUsage}</div>
          <div className={clsx('text-sm mt-1', muted)}>∅ {avgPerDay} pro Tag</div>
        </Card>

        <Card className="p-6">
          <div className={clsx('text-sm mb-1', muted)}>Aktive Agents</div>
          <div className={clsx('text-3xl font-bold', heading)}>{stats.agentUsage.length}</div>
          <div className={clsx('text-sm mt-1', muted)}>haben Templates verwendet</div>
        </Card>
      </div>

      <Card className="p-6">
        <h3 className={clsx('text-lg font-semibold mb-4', heading)}>Top Templates</h3>

        {stats.topTemplates.length === 0 ? (
          <p className={clsx('text-center py-8', muted)}>Keine Daten im ausgewählten Zeitraum verfügbar.</p>
        ) : (
          <div
            className={clsx(
              'rounded-lg overflow-hidden border',
              isDark ? 'border-slate-600' : 'border-gray-200',
            )}
          >
            {stats.topTemplates.map((template, index) => (
              <div
                key={template.id}
                className={clsx(
                  'flex items-center gap-4 px-4 py-3',
                  listRowStripeClasses(isDark, index, { hover: false }),
                )}
              >
                <div
                  className={clsx('text-2xl font-bold w-8 text-center', isDark ? 'text-slate-500' : 'text-gray-300')}
                >
                  {index + 1}
                </div>
                <div className="flex-1 min-w-0">
                  <div className={clsx('font-medium truncate', heading)}>{template.title}</div>
                  <div className={clsx('text-sm', muted)}>{template.category}</div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-fin1-primary">{template.usageCount}</div>
                  <div className={clsx('text-xs', muted)}>Verwendungen</div>
                </div>
                <div className="w-24">
                  <div
                    className={clsx('h-2 rounded-full overflow-hidden', isDark ? 'bg-slate-700' : 'bg-gray-200')}
                  >
                    <div
                      className="h-full bg-fin1-primary rounded-full"
                      style={{
                        width: `${maxTopUsage > 0 ? Math.round((template.usageCount / maxTopUsage) * 100) : 0}%`,
                      }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      <Card className="p-6">
        <h3 className={clsx('text-lg font-semibold mb-4', heading)}>Nutzung nach Agent</h3>

        {stats.agentUsage.length === 0 ? (
          <p className={clsx('text-center py-8', muted)}>Keine Daten im ausgewählten Zeitraum verfügbar.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className={tableTheadSurfaceClasses(isDark)}>
                <tr>
                  <th className={clsx('text-left py-2 text-sm font-medium', tableHeaderCellTextClasses(isDark))}>
                    Agent ID
                  </th>
                  <th className={clsx('text-right py-2 text-sm font-medium', tableHeaderCellTextClasses(isDark))}>
                    Verwendungen
                  </th>
                  <th className={clsx('text-right py-2 text-sm font-medium', tableHeaderCellTextClasses(isDark))}>
                    % der Gesamtnutzung
                  </th>
                </tr>
              </thead>
              <tbody className={tableBodyDivideClasses(isDark)}>
                {stats.agentUsage.map((agent, index) => (
                  <tr key={agent.agentId} className={listRowStripeClasses(isDark, index, { hover: false })}>
                    <td className={clsx('py-3 font-mono text-sm', heading)}>{agent.agentId}</td>
                    <td className={clsx('py-3 text-right font-medium', heading)}>{agent.usageCount}</td>
                    <td className={clsx('py-3 text-right', muted)}>
                      {stats.totalUsage > 0
                        ? `${((agent.usageCount / stats.totalUsage) * 100).toFixed(1)}%`
                        : '—'}
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

export function UsageStats(): JSX.Element {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [picker, setPicker] = useState<Picker>('d30');
  const [committedCustom, setCommittedCustom] = useState(defaultLast30);
  const [draftFrom, setDraftFrom] = useState(committedCustom.from);
  const [draftTo, setDraftTo] = useState(committedCustom.to);
  const [rangeError, setRangeError] = useState<string | null>(null);

  const selectPicker = (p: Picker) => {
    setRangeError(null);
    if (p === 'custom') {
      setDraftFrom(committedCustom.from);
      setDraftTo(committedCustom.to);
    }
    setPicker(p);
  };

  const applyCustomRange = () => {
    setRangeError(null);
    const s = parseLocalDateStart(draftFrom);
    const e = parseLocalDateEnd(draftTo);
    if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime())) {
      setRangeError('Bitte gültige Daten wählen.');
      return;
    }
    if (s > e) {
      setRangeError('„Von“ muss vor oder gleich „Bis“ liegen.');
      return;
    }
    if (e.getTime() - s.getTime() > MAX_RANGE_MS) {
      setRangeError('Zeitraum darf höchstens 366 Tage betragen.');
      return;
    }
    setCommittedCustom({ from: draftFrom, to: draftTo });
  };

  const statsParams: GetTemplateUsageStatsParams = useMemo(() => {
    if (picker !== 'custom') {
      const days = picker === 'd7' ? 7 : picker === 'd90' ? 90 : 30;
      return { days };
    }
    return {
      startDate: parseLocalDateStart(committedCustom.from).toISOString(),
      endDate: parseLocalDateEnd(committedCustom.to).toISOString(),
    };
  }, [picker, committedCustom.from, committedCustom.to]);

  const queryKey = useMemo(
    () =>
      picker === 'custom'
        ? (['templateUsageStats', 'custom', committedCustom.from, committedCustom.to] as const)
        : (['templateUsageStats', 'rolling', picker] as const),
    [picker, committedCustom.from, committedCustom.to],
  );

  const { data, isLoading, error, refetch, isFetching } = useQuery({
    queryKey,
    queryFn: () => getTemplateUsageStats(statsParams),
    staleTime: 30_000,
  });

  const muted = isDark ? 'text-slate-400' : 'text-gray-500';
  const heading = isDark ? 'text-slate-100' : 'text-gray-900';
  const chip = (active: boolean) =>
    clsx(
      'px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors',
      active
        ? 'border-fin1-primary bg-fin1-primary text-white'
        : isDark
          ? 'border-slate-600 text-slate-200 hover:bg-slate-800'
          : 'border-gray-300 text-gray-700 hover:bg-gray-50',
    );
  const inputCls = clsx(
    'px-3 py-2 rounded-lg border text-sm',
    isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
  );

  return (
    <div className="space-y-4">
      <Card className="p-4">
        <div className={clsx('text-sm font-medium mb-3', heading)}>Zeitraum für Statistiken</div>
        <div className="flex flex-wrap items-center gap-2">
          <button type="button" className={chip(picker === 'd7')} onClick={() => selectPicker('d7')}>
            7 Tage
          </button>
          <button type="button" className={chip(picker === 'd30')} onClick={() => selectPicker('d30')}>
            30 Tage
          </button>
          <button type="button" className={chip(picker === 'd90')} onClick={() => selectPicker('d90')}>
            90 Tage
          </button>
          <button type="button" className={chip(picker === 'custom')} onClick={() => selectPicker('custom')}>
            Benutzerdefiniert
          </button>
          <Button variant="secondary" size="sm" type="button" onClick={() => refetch()} disabled={isFetching}>
            {isFetching ? 'Laden…' : 'Aktualisieren'}
          </Button>
        </div>

        {picker === 'custom' && (
          <div className="mt-4 flex flex-col sm:flex-row sm:flex-wrap sm:items-end gap-3">
            <div>
              <label className={clsx('block text-xs mb-1', muted)} htmlFor="usage-stats-from">
                Von
              </label>
              <input
                id="usage-stats-from"
                type="date"
                value={draftFrom}
                onChange={(e) => setDraftFrom(e.target.value)}
                className={inputCls}
              />
            </div>
            <div>
              <label className={clsx('block text-xs mb-1', muted)} htmlFor="usage-stats-to">
                Bis
              </label>
              <input
                id="usage-stats-to"
                type="date"
                value={draftTo}
                onChange={(e) => setDraftTo(e.target.value)}
                className={inputCls}
              />
            </div>
            <Button type="button" size="sm" onClick={applyCustomRange}>
              Zeitraum anwenden
            </Button>
            {rangeError && <p className="text-sm text-red-500 w-full sm:w-auto">{rangeError}</p>}
          </div>
        )}
      </Card>

      {isLoading && (
        <div className="flex justify-center py-16">
          <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full" />
        </div>
      )}

      {error && (
        <Card>
          <div className="text-center py-8">
            <p className="text-red-500">
              {error instanceof Error ? error.message : 'Statistiken konnten nicht geladen werden.'}
            </p>
            <p className={clsx('text-sm mt-2', muted)}>
              Fehlt die Berechtigung „Analytics“, sind keine Nutzungsdaten verfügbar.
            </p>
            <Button variant="secondary" className="mt-4" type="button" onClick={() => refetch()}>
              Erneut versuchen
            </Button>
          </div>
        </Card>
      )}

      {!isLoading && !error && data && <UsageStatsContent stats={data} />}
    </div>
  );
}
