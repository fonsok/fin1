import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { useAuth } from '../../context/AuthContext';
import { Card, Button } from '../../components/ui';
import { formatDateTime } from '../../utils/format';

interface ApprovalRequest {
  objectId: string;
  requestType: string;
  requesterId: string;
  requesterEmail?: string;
  requesterRole: string;
  status: string;
  metadata?: Record<string, unknown>;
  expiresAt: string;
  createdAt: string;
}

export function ApprovalsListPage() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [selectedRequest, setSelectedRequest] = useState<ApprovalRequest | null>(null);
  const [actionType, setActionType] = useState<'approve' | 'reject' | null>(null);
  const [notes, setNotes] = useState('');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['pendingApprovals'],
    queryFn: () => cloudFunction<{ requests: ApprovalRequest[] }>('getPendingApprovals'),
  });

  const approveMutation = useMutation({
    mutationFn: ({ requestId, notes }: { requestId: string; notes?: string }) =>
      cloudFunction('approveRequest', { requestId, notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      closeModal();
    },
  });

  const rejectMutation = useMutation({
    mutationFn: ({ requestId, reason }: { requestId: string; reason: string }) =>
      cloudFunction('rejectRequest', { requestId, reason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      closeModal();
    },
  });

  const closeModal = () => {
    setSelectedRequest(null);
    setActionType(null);
    setNotes('');
  };

  const getRequestTypeLabel = (type: string): string => {
    const labels: Record<string, string> = {
      'correction': 'Korrekturbuchung',
      'user_delete': 'Benutzer löschen',
      'large_transaction': 'Große Transaktion',
      'config_change': 'Konfigurationsänderung',
      'role_change': 'Rollenänderung',
    };
    return labels[type] || type || '-';
  };

  const isOwnRequest = (request: ApprovalRequest): boolean => {
    return request.requesterId === user?.objectId;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold">4-Augen-Freigaben</h2>
            <p className="text-sm text-gray-500 mt-1">
              Ausstehende Anfragen, die Ihre Genehmigung benötigen
            </p>
          </div>
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
            <p className="text-red-500">Fehler beim Laden der Anfragen</p>
          </div>
        ) : !data?.requests?.length ? (
          <div className="p-8 text-center">
            <svg className="w-12 h-12 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-gray-500">Keine ausstehenden Freigaben</p>
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
                    Angefragt von
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Details
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Läuft ab
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Aktionen
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {data.requests.map((request) => (
                  <tr key={request.objectId} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-medium text-gray-900">
                        {getRequestTypeLabel(request.requestType)}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <p className="text-sm text-gray-900">
                        {request.requesterEmail || request.requesterId}
                      </p>
                      <p className="text-xs text-gray-500">{request.requesterRole}</p>
                    </td>
                    <td className="px-6 py-4">
                      <p className="text-sm text-gray-600 truncate max-w-xs">
                        {request.metadata?.reason as string || '-'}
                      </p>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDateTime(request.expiresAt)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      {isOwnRequest(request) ? (
                        <span className="text-sm text-gray-400">Eigene Anfrage</span>
                      ) : (
                        <div className="flex gap-2 justify-end">
                          <Button
                            variant="success"
                            size="sm"
                            onClick={() => {
                              setSelectedRequest(request);
                              setActionType('approve');
                            }}
                          >
                            Genehmigen
                          </Button>
                          <Button
                            variant="danger"
                            size="sm"
                            onClick={() => {
                              setSelectedRequest(request);
                              setActionType('reject');
                            }}
                          >
                            Ablehnen
                          </Button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {/* Action Modal */}
      {selectedRequest && actionType && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg">
            <h3 className="text-lg font-semibold mb-4">
              {actionType === 'approve' ? 'Anfrage genehmigen' : 'Anfrage ablehnen'}
            </h3>

            <div className="space-y-3 mb-4 p-4 bg-gray-50 rounded-lg">
              <div>
                <span className="text-sm text-gray-500">Typ:</span>
                <span className="ml-2 text-sm font-medium">
                  {getRequestTypeLabel(selectedRequest.requestType)}
                </span>
              </div>
              <div>
                <span className="text-sm text-gray-500">Von:</span>
                <span className="ml-2 text-sm">
                  {selectedRequest.requesterEmail || selectedRequest.requesterId}
                </span>
              </div>
              {typeof selectedRequest.metadata?.reason === 'string' && (
                <div>
                  <span className="text-sm text-gray-500">Begründung:</span>
                  <p className="text-sm mt-1">{selectedRequest.metadata.reason}</p>
                </div>
              )}
            </div>

            <label className="block text-sm font-medium text-gray-700 mb-1">
              {actionType === 'approve' ? 'Notizen (optional)' : 'Ablehnungsgrund (erforderlich)'}
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4"
              rows={3}
              placeholder={actionType === 'approve' ? 'Optionale Notizen...' : 'Grund für die Ablehnung...'}
              required={actionType === 'reject'}
            />

            <div className="flex gap-3 justify-end">
              <Button variant="secondary" onClick={closeModal}>
                Abbrechen
              </Button>
              <Button
                variant={actionType === 'approve' ? 'success' : 'danger'}
                loading={approveMutation.isPending || rejectMutation.isPending}
                disabled={actionType === 'reject' && !notes.trim()}
                onClick={() => {
                  if (actionType === 'approve') {
                    approveMutation.mutate({
                      requestId: selectedRequest.objectId,
                      notes: notes || undefined,
                    });
                  } else {
                    rejectMutation.mutate({
                      requestId: selectedRequest.objectId,
                      reason: notes,
                    });
                  }
                }}
              >
                {actionType === 'approve' ? 'Genehmigen' : 'Ablehnen'}
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
