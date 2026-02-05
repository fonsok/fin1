import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { Card, Button, Badge } from '../../components/ui';
import { formatDateTime } from '../../utils/format';

interface ComplianceEvent {
  objectId: string;
  eventType: string;
  severity: string;
  userId?: string;
  userEmail?: string;
  description: string;
  reviewed: boolean;
  reviewedBy?: string;
  reviewedAt?: string;
  reviewNotes?: string;
  metadata?: Record<string, unknown>;
  createdAt: string;
}

export function ComplianceEventsPage() {
  const queryClient = useQueryClient();
  const [severityFilter, setSeverityFilter] = useState<string>('');
  const [reviewedFilter, setReviewedFilter] = useState<string>('');
  const [selectedEvent, setSelectedEvent] = useState<ComplianceEvent | null>(null);
  const [reviewNotes, setReviewNotes] = useState('');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['complianceEvents', severityFilter, reviewedFilter],
    queryFn: () => cloudFunction<{ events: ComplianceEvent[]; total: number }>('getComplianceEvents', {
      severity: severityFilter || undefined,
      reviewed: reviewedFilter === 'true' ? true : reviewedFilter === 'false' ? false : undefined,
      limit: 50,
    }),
  });

  const reviewMutation = useMutation({
    mutationFn: ({ eventId, notes }: { eventId: string; notes: string }) =>
      cloudFunction('reviewComplianceEvent', { eventId, notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['complianceEvents'] });
      setSelectedEvent(null);
      setReviewNotes('');
    },
  });

  const getSeverityVariant = (severity: string): 'success' | 'warning' | 'danger' | 'info' | 'neutral' => {
    switch (severity?.toLowerCase()) {
      case 'critical': return 'danger';
      case 'high': return 'danger';
      case 'medium': return 'warning';
      case 'low': return 'info';
      default: return 'neutral';
    }
  };

  const getSeverityLabel = (severity: string): string => {
    switch (severity?.toLowerCase()) {
      case 'critical': return 'Kritisch';
      case 'high': return 'Hoch';
      case 'medium': return 'Mittel';
      case 'low': return 'Niedrig';
      default: return severity || '-';
    }
  };

  const getEventTypeLabel = (type: string): string => {
    const labels: Record<string, string> = {
      'aml_check_failed': 'AML-Prüfung fehlgeschlagen',
      'suspicious_activity': 'Verdächtige Aktivität',
      'large_transaction': 'Große Transaktion',
      'login_from_new_device': 'Login von neuem Gerät',
      'failed_login_attempt': 'Fehlgeschlagener Login',
      'kyc_document_uploaded': 'KYC-Dokument hochgeladen',
      'account_locked': 'Konto gesperrt',
      'password_changed': 'Passwort geändert',
    };
    return labels[type] || type || '-';
  };

  return (
    <div className="space-y-6">
      {/* Filters */}
      <Card>
        <div className="flex flex-col sm:flex-row gap-4">
          <select
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
          >
            <option value="">Alle Schweregrade</option>
            <option value="critical">Kritisch</option>
            <option value="high">Hoch</option>
            <option value="medium">Mittel</option>
            <option value="low">Niedrig</option>
          </select>

          <select
            value={reviewedFilter}
            onChange={(e) => setReviewedFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
          >
            <option value="">Alle</option>
            <option value="false">Nicht geprüft</option>
            <option value="true">Geprüft</option>
          </select>

          <Button variant="secondary" onClick={() => refetch()}>
            Aktualisieren
          </Button>
        </div>
      </Card>

      {/* Results */}
      <Card padding="none">
        {isLoading ? (
          <div className="p-8 text-center">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className="text-gray-500 mt-4">Laden...</p>
          </div>
        ) : error ? (
          <div className="p-8 text-center">
            <p className="text-red-500">Fehler beim Laden der Events</p>
          </div>
        ) : !data?.events?.length ? (
          <div className="p-8 text-center">
            <svg className="w-12 h-12 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
            <p className="text-gray-500">Keine Compliance-Events gefunden</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Typ
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Beschreibung
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Schweregrad
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Datum
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Aktionen
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {data.events.map((event) => (
                  <tr key={event.objectId} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-medium text-gray-900">
                        {getEventTypeLabel(event.eventType)}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <p className="text-sm text-gray-600 truncate max-w-xs">
                        {event.description || '-'}
                      </p>
                      {event.userEmail && (
                        <p className="text-xs text-gray-400">{event.userEmail}</p>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Badge variant={getSeverityVariant(event.severity)}>
                        {getSeverityLabel(event.severity)}
                      </Badge>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Badge variant={event.reviewed ? 'success' : 'warning'}>
                        {event.reviewed ? 'Geprüft' : 'Offen'}
                      </Badge>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDateTime(event.createdAt)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      {!event.reviewed && (
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => setSelectedEvent(event)}
                        >
                          Prüfen
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {/* Review Modal */}
      {selectedEvent && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg">
            <h3 className="text-lg font-semibold mb-4">Event prüfen</h3>

            <div className="space-y-3 mb-4">
              <div>
                <span className="text-sm text-gray-500">Typ:</span>
                <span className="ml-2 text-sm font-medium">{getEventTypeLabel(selectedEvent.eventType)}</span>
              </div>
              <div>
                <span className="text-sm text-gray-500">Beschreibung:</span>
                <p className="text-sm mt-1">{selectedEvent.description}</p>
              </div>
              <div>
                <span className="text-sm text-gray-500">Schweregrad:</span>
                <Badge variant={getSeverityVariant(selectedEvent.severity)} className="ml-2">
                  {getSeverityLabel(selectedEvent.severity)}
                </Badge>
              </div>
            </div>

            <label className="block text-sm font-medium text-gray-700 mb-1">
              Prüfnotizen
            </label>
            <textarea
              value={reviewNotes}
              onChange={(e) => setReviewNotes(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4"
              rows={3}
              placeholder="Notizen zur Prüfung..."
            />

            <div className="flex gap-3 justify-end">
              <Button
                variant="secondary"
                onClick={() => {
                  setSelectedEvent(null);
                  setReviewNotes('');
                }}
              >
                Abbrechen
              </Button>
              <Button
                variant="success"
                loading={reviewMutation.isPending}
                onClick={() => {
                  reviewMutation.mutate({
                    eventId: selectedEvent.objectId,
                    notes: reviewNotes,
                  });
                }}
              >
                Als geprüft markieren
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
