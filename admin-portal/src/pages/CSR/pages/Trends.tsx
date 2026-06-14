import { useState, useMemo, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import clsx from 'clsx';
import { Card, Badge, PaginationBar } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { getSupportTrends, type SupportTrend } from '../api';

import {
  adminCaption,
  adminEmphasisSoft,
  adminEmptyIcon,
  adminInteractiveIcon,
  adminLabel,
  adminMonoTicketId,
  adminMuted,
  adminPrimary,
} from '../../../utils/adminThemeClasses';
import { severityIconWellClasses, severityPanelClasses, severityToChipVariant } from '../../../utils/chipVariants';

const TRENDS_PAGE_SIZE = 50;

export function TrendsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const [selectedTrend, setSelectedTrend] = useState<SupportTrend | null>(null);
  const [page, setPage] = useState(0);

  const { data, isLoading, error } = useQuery({
    queryKey: ['support-trends', 2],
    queryFn: () => getSupportTrends(2),
    staleTime: 60_000,
  });

  const trends = useMemo(() => data?.trends ?? [], [data?.trends]);
  const meta = data?.meta;

  const trendsTotal = trends.length;
  const trendsTotalPages = Math.max(1, Math.ceil(trendsTotal / TRENDS_PAGE_SIZE));
  const pagedTrends = useMemo(
    () => trends.slice(page * TRENDS_PAGE_SIZE, (page + 1) * TRENDS_PAGE_SIZE),
    [trends, page],
  );

  useEffect(() => {
    setPage(0);
  }, [trendsTotal]);

  useEffect(() => {
    if (page > 0 && page >= trendsTotalPages) {
      setPage(Math.max(0, trendsTotalPages - 1));
    }
  }, [page, trendsTotalPages]);

  const getTrendIcon = (type: string) => {
    switch (type) {
      case 'volumeSpike':
        return (
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
          </svg>
        );
      default:
        return (
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className={clsx('text-2xl font-bold', adminPrimary(isDark))}>
          Trends & Muster
        </h1>
        <div className="flex items-center gap-2">
          {meta?.truncated && (
            <Badge variant="warning">Stichprobe (Server-Aggregation)</Badge>
          )}
          <Badge variant="info">{trends.length} Trends erkannt</Badge>
        </div>
      </div>

      {isLoading && (
        <Card>
          <p className={clsx('text-center py-8', adminMuted(isDark))}>Trends werden berechnet...</p>
        </Card>
      )}

      {error && (
        <Card>
          <p className={clsx('text-center py-8 text-red-500')}>
            {error instanceof Error ? error.message : 'Fehler beim Laden der Trends'}
          </p>
        </Card>
      )}

      {!isLoading && !error && trends.length === 0 ? (
        <Card>
          <div className="text-center py-8">
            <svg
              className={clsx('w-12 h-12 mx-auto mb-4', adminEmptyIcon(isDark))}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <p className={clsx(adminMuted(isDark))}>Keine Trends erkannt</p>
            <p className={clsx('text-sm mt-2', adminCaption(isDark))}>
              Alle Metriken sind im normalen Bereich
            </p>
          </div>
        </Card>
      ) : null}

      {!isLoading && !error && trends.length > 0 ? (
        <Card padding="none">
          <>
            <div className="grid grid-cols-1 gap-4 p-4">
              {pagedTrends.map((trend) => (
                <Card
                  key={trend.id}
                  className={clsx(
                    'cursor-pointer hover:shadow-lg transition-shadow',
                    severityPanelClasses(trend.severity, isDark),
                  )}
                  onClick={() => setSelectedTrend(trend)}
                >
                  <div className="flex items-start gap-4">
                    <div className={severityIconWellClasses(trend.severity, isDark)}>
                      {getTrendIcon(trend.type)}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center justify-between mb-2">
                        <h3 className="text-lg font-semibold">{trend.title}</h3>
                        <Badge variant={severityToChipVariant(trend.severity)}>
                          {trend.severity === 'critical' ? 'Kritisch' : trend.severity === 'warning' ? 'Warnung' : 'Info'}
                        </Badge>
                      </div>
                      <p className="text-sm mb-3">{trend.description}</p>
                      <div className="flex items-center gap-4 text-sm">
                        <span>{trend.ticketCount} Tickets</span>
                        <span>{trend.affectedCustomers} betroffene Kunden</span>
                        {trend.percentageChange > 0 && (
                          <span>+{Math.round(trend.percentageChange)}%</span>
                        )}
                      </div>
                      <div
                        className={clsx(
                          'mt-3 pt-3 border-t',
                          isDark ? 'border-white/10' : 'border-black/10',
                        )}
                      >
                        <p className="text-sm font-medium">Empfohlene Maßnahme:</p>
                        <p className="text-sm opacity-95">{trend.suggestedAction}</p>
                      </div>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
            <PaginationBar
              page={page}
              pageSize={TRENDS_PAGE_SIZE}
              total={trendsTotal}
              itemLabel="Trends"
              isDark={isDark}
              onPageChange={setPage}
            />
          </>
        </Card>
      ) : null}

      {selectedTrend && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" onClick={() => setSelectedTrend(null)}>
          <Card className="w-full max-w-2xl m-4" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className={clsx('text-xl font-semibold', adminPrimary(isDark))}>
                {selectedTrend.title}
              </h2>
              <button
                type="button"
                onClick={() => setSelectedTrend(null)}
                className={clsx('rounded p-1', adminInteractiveIcon(isDark))}
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <h3 className={clsx('font-semibold mb-2', adminEmphasisSoft(isDark))}>Beschreibung</h3>
                <p className={clsx(adminLabel(isDark))}>{selectedTrend.description}</p>
              </div>
              <div>
                <h3 className={clsx('font-semibold mb-2', adminEmphasisSoft(isDark))}>Empfohlene Maßnahme</h3>
                <p className={clsx(adminLabel(isDark))}>{selectedTrend.suggestedAction}</p>
              </div>
              <div>
                <h3 className={clsx('font-semibold mb-2', adminEmphasisSoft(isDark))}>Betroffene Tickets</h3>
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {selectedTrend.relatedTicketIds.map((ticketId) => (
                    <button
                      key={ticketId}
                      type="button"
                      onClick={() => {
                        navigate(`/csr/tickets/${ticketId}`);
                        setSelectedTrend(null);
                      }}
                      className={clsx(
                        'w-full text-left p-2 border rounded cursor-pointer',
                        isDark
                          ? 'border-slate-600 hover:bg-slate-700/50'
                          : 'border-gray-200 hover:bg-gray-50',
                      )}
                    >
                      <span className={clsx('text-sm font-mono', adminMonoTicketId(isDark))}>
                        Ticket {ticketId.slice(0, 8)}…
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}