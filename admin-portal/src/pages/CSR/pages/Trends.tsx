import { useState, useMemo, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Card, Badge, PaginationBar } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { getSupportTickets } from '../api';
import type { SupportTicket } from '../types';

interface SupportTrend {
  id: string;
  type: 'volumeSpike' | 'recurringIssue' | 'longResolutionTime' | 'highEscalationRate' | 'negativeCSAT' | 'reopenedTickets';
  title: string;
  description: string;
  severity: 'info' | 'warning' | 'critical';
  ticketCount: number;
  affectedCustomers: number;
  percentageChange: number;
  detectedAt: string;
  relatedTicketIds: string[];
  suggestedAction: string;
}

const TRENDS_PAGE_SIZE = 50;

/** Simple trend detection (can be enhanced with backend API) */
function detectSupportTrends(tickets: SupportTicket[]): SupportTrend[] {
  if (!tickets.length) return [];

    const trends: SupportTrend[] = [];
    const now = new Date();
    const lastWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const previousWeek = new Date(lastWeek.getTime() - 7 * 24 * 60 * 60 * 1000);

    const currentWeekTickets = tickets.filter(t => new Date(t.createdAt) >= lastWeek);
    const previousWeekTickets = tickets.filter(
      t => new Date(t.createdAt) >= previousWeek && new Date(t.createdAt) < lastWeek
    );

    // 1. Volume Spike Detection
    if (currentWeekTickets.length > 0 && previousWeekTickets.length > 0) {
      const percentageChange = ((currentWeekTickets.length - previousWeekTickets.length) / previousWeekTickets.length) * 100;
      if (percentageChange >= 50) {
        trends.push({
          id: 'volume-spike',
          type: 'volumeSpike',
          title: `Ticket-Volumen um ${Math.round(percentageChange)}% gestiegen`,
          description: `${currentWeekTickets.length} Tickets diese Woche (zuvor: ${previousWeekTickets.length})`,
          severity: percentageChange > 100 ? 'critical' : 'warning',
          ticketCount: currentWeekTickets.length,
          affectedCustomers: new Set(currentWeekTickets.map(t => t.userId)).size,
          percentageChange,
          detectedAt: new Date().toISOString(),
          relatedTicketIds: currentWeekTickets.slice(0, 10).map(t => t.objectId),
          suggestedAction: 'Überprüfen Sie die häufigsten Ticket-Themen und erwägen Sie zusätzliche Ressourcen.',
        });
      }
    }

    // 2. Recurring Issues Detection
    const categoryCounts: Record<string, number> = {};
    currentWeekTickets.forEach(ticket => {
      const category = ticket.category || 'Other';
      categoryCounts[category] = (categoryCounts[category] || 0) + 1;
    });

    Object.entries(categoryCounts).forEach(([category, count]) => {
      if (count >= 5) {
        const relatedTickets = currentWeekTickets.filter(t => (t.category || 'Other') === category);
        trends.push({
          id: `recurring-${category}`,
          type: 'recurringIssue',
          title: `${count} Tickets zu "${category}"`,
          description: 'Wiederkehrendes Problem erkannt. Möglicherweise ist eine technische Lösung erforderlich.',
          severity: count >= 10 ? 'critical' : 'warning',
          ticketCount: count,
          affectedCustomers: new Set(relatedTickets.map(t => t.userId)).size,
          percentageChange: 0,
          detectedAt: new Date().toISOString(),
          relatedTicketIds: relatedTickets.slice(0, 10).map(t => t.objectId),
          suggestedAction: 'Prüfen Sie ob ein Produktfehler vorliegt oder die Dokumentation verbessert werden kann.',
        });
      }
    });

    // 3. Long Resolution Time Detection
    const unresolvedTickets = currentWeekTickets.filter(
      t => t.status !== 'resolved' && t.status !== 'closed'
    );
    const oldTickets = unresolvedTickets.filter(t => {
      const createdAt = new Date(t.createdAt);
      const hoursOld = (now.getTime() - createdAt.getTime()) / (1000 * 60 * 60);
      return hoursOld > 48;
    });

    if (oldTickets.length > 0) {
      trends.push({
        id: 'long-resolution',
        type: 'longResolutionTime',
        title: `${oldTickets.length} Tickets älter als 48 Stunden`,
        description: 'Diese Tickets benötigen dringend Aufmerksamkeit.',
        severity: oldTickets.length >= 10 ? 'critical' : 'warning',
        ticketCount: oldTickets.length,
        affectedCustomers: new Set(oldTickets.map(t => t.userId)).size,
        percentageChange: 0,
        detectedAt: new Date().toISOString(),
        relatedTicketIds: oldTickets.slice(0, 10).map(t => t.objectId),
        suggestedAction: 'Priorisieren Sie diese Tickets und weisen Sie sie erfahrenen Agents zu.',
      });
    }

    // 4. High Escalation Rate Detection
    const escalatedTickets = currentWeekTickets.filter(t => t.priority === 'urgent' || t.priority === 'high');
    const escalationRate = (escalatedTickets.length / currentWeekTickets.length) * 100;
    if (escalationRate >= 20 && currentWeekTickets.length > 0) {
      trends.push({
        id: 'high-escalation',
        type: 'highEscalationRate',
        title: `Hohe Eskalationsrate: ${Math.round(escalationRate)}%`,
        description: `${escalatedTickets.length} von ${currentWeekTickets.length} Tickets sind eskaliert`,
        severity: escalationRate >= 30 ? 'critical' : 'warning',
        ticketCount: escalatedTickets.length,
        affectedCustomers: new Set(escalatedTickets.map(t => t.userId)).size,
        percentageChange: escalationRate,
        detectedAt: new Date().toISOString(),
        relatedTicketIds: escalatedTickets.slice(0, 10).map(t => t.objectId),
        suggestedAction: 'Analysieren Sie die Ursachen für die hohe Eskalationsrate.',
      });
    }

    return trends;
}

export function TrendsPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const navigate = useNavigate();
  const [selectedTrend, setSelectedTrend] = useState<SupportTrend | null>(null);
  const [page, setPage] = useState(0);

  const { data: tickets } = useQuery({
    queryKey: ['csr-tickets-all'],
    queryFn: () => getSupportTickets(),
  });

  const trends = useMemo(() => detectSupportTrends(tickets ?? []), [tickets]);
  const trendsTotal = trends.length;
  const trendsTotalPages = Math.max(1, Math.ceil(trendsTotal / TRENDS_PAGE_SIZE));
  const pagedTrends = useMemo(
    () => trends.slice(page * TRENDS_PAGE_SIZE, (page + 1) * TRENDS_PAGE_SIZE),
    [trends, page]
  );

  useEffect(() => {
    setPage(0);
  }, [trendsTotal]);

  useEffect(() => {
    if (page > 0 && page >= trendsTotalPages) {
      setPage(Math.max(0, trendsTotalPages - 1));
    }
  }, [page, trendsTotalPages]);

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'critical': return 'bg-red-100 text-red-800 border-red-300';
      case 'warning': return 'bg-orange-100 text-orange-800 border-orange-300';
      case 'info': return 'bg-blue-100 text-blue-800 border-blue-300';
      default: return 'bg-gray-100 text-gray-800 border-gray-300';
    }
  };

  const getTrendIcon = (type: string) => {
    switch (type) {
      case 'volumeSpike':
        return (
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
          </svg>
        );
      case 'recurringIssue':
        return (
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        );
      case 'longResolutionTime':
        return (
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      case 'highEscalationRate':
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
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Trends & Muster</h1>
        <Badge variant="info">{trends.length} Trends erkannt</Badge>
      </div>

      {trends.length === 0 ? (
        <Card>
          <div className="text-center py-8">
            <svg
              className="w-12 h-12 text-gray-300 mx-auto mb-4"
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
            <p className="text-gray-500">Keine Trends erkannt</p>
            <p className="text-sm text-gray-400 mt-2">Alle Metriken sind im normalen Bereich</p>
          </div>
        </Card>
      ) : (
        <Card padding="none">
          <>
            <div className="grid grid-cols-1 gap-4 p-4">
              {pagedTrends.map((trend) => (
                <Card
                  key={trend.id}
                  className={`border-2 cursor-pointer hover:shadow-lg transition-shadow ${getSeverityColor(trend.severity)}`}
                  onClick={() => setSelectedTrend(trend)}
                >
                  <div className="flex items-start gap-4">
                    <div className={`p-2 rounded-lg ${getSeverityColor(trend.severity)}`}>
                      {getTrendIcon(trend.type)}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center justify-between mb-2">
                        <h3 className="text-lg font-semibold">{trend.title}</h3>
                        <Badge variant={trend.severity === 'critical' ? 'danger' : trend.severity === 'warning' ? 'warning' : 'info'}>
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
                      <div className="mt-3 pt-3 border-t">
                        <p className="text-sm font-medium">Empfohlene Maßnahme:</p>
                        <p className="text-sm">{trend.suggestedAction}</p>
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
      )}

      {/* Trend Detail Modal */}
      {selectedTrend && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" onClick={() => setSelectedTrend(null)}>
          <Card className="w-full max-w-2xl m-4" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">{selectedTrend.title}</h2>
              <button
                onClick={() => setSelectedTrend(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <h3 className="font-semibold mb-2">Beschreibung</h3>
                <p>{selectedTrend.description}</p>
              </div>
              <div>
                <h3 className="font-semibold mb-2">Empfohlene Maßnahme</h3>
                <p>{selectedTrend.suggestedAction}</p>
              </div>
              <div>
                <h3 className="font-semibold mb-2">Betroffene Tickets</h3>
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {selectedTrend.relatedTicketIds.map((ticketId) => {
                    const ticket = tickets?.find(t => t.objectId === ticketId);
                    if (!ticket) return null;
                    return (
                      <div
                        key={ticketId}
                        onClick={() => {
                          navigate(`/csr/tickets/${ticketId}`);
                          setSelectedTrend(null);
                        }}
                        className="p-2 border rounded hover:bg-gray-50 cursor-pointer"
                      >
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-mono">#{ticket.ticketNumber || ticketId.slice(0, 8)}</span>
                          <span className="text-sm">{ticket.subject}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
