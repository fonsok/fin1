import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../api/admin';
import { useAuth } from '../../context/AuthContext';
import { Card, Button, Badge } from '../../components/ui';
import { formatDateTime, formatCurrency, formatPercentage, formatRelative } from '../../utils/format';

interface ApprovalRequest {
  objectId: string;
  requestType: string;
  requesterId: string;
  requesterEmail?: string;
  requesterRole: string;
  status: string;
  approverId?: string;
  approverEmail?: string;
  approverNotes?: string;
  rejectionReason?: string;
  withdrawnReason?: string;
  metadata?: Record<string, unknown>;
  expiresAt: string;
  createdAt: string;
  updatedAt: string;
}

interface ApprovalsResponse {
  requests: ApprovalRequest[];
  ownPending: ApprovalRequest[];
  history: ApprovalRequest[];
  allRequests: ApprovalRequest[];
}

type TabId = 'pending' | 'own' | 'all' | 'history';

const CONFIG_PARAM_TYPES: Record<string, 'percentage' | 'currency'> = {
  traderCommissionRate: 'percentage',
  platformServiceChargeRate: 'percentage',
  initialAccountBalance: 'currency',
  minimumCashReserve: 'currency',
  poolBalanceDistributionThreshold: 'currency',
};

const PARAM_DISPLAY_NAMES: Record<string, string> = {
  traderCommissionRate: 'Trader-Provision',
  platformServiceChargeRate: 'Plattform-Servicegebühr',
  initialAccountBalance: 'Startguthaben',
  minimumCashReserve: 'Mindest-Bargeldreserve',
  poolBalanceDistributionThreshold: 'Pool-Verteilungsschwelle',
};

function formatConfigValue(paramName: string, value: unknown): string {
  const numVal = Number(value);
  if (isNaN(numVal)) return String(value);
  const type = CONFIG_PARAM_TYPES[paramName];
  if (type === 'percentage') return formatPercentage(numVal);
  if (type === 'currency') return formatCurrency(numVal);
  return String(value);
}

function getParamDisplayName(paramName: string): string {
  return PARAM_DISPLAY_NAMES[paramName] || paramName;
}

function getStatusBadge(status: string) {
  const config: Record<string, { label: string; variant: 'success' | 'warning' | 'danger' | 'info' | 'neutral' }> = {
    pending: { label: 'Ausstehend', variant: 'warning' },
    approved: { label: 'Genehmigt', variant: 'success' },
    rejected: { label: 'Abgelehnt', variant: 'danger' },
    expired: { label: 'Abgelaufen', variant: 'neutral' },
    withdrawn: { label: 'Zurückgezogen', variant: 'info' },
  };
  const c = config[status] || { label: status, variant: 'neutral' };
  return <Badge variant={c.variant}>{c.label}</Badge>;
}

function getRequestTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    correction: 'Korrekturbuchung',
    user_delete: 'Benutzer löschen',
    large_transaction: 'Große Transaktion',
    config_change: 'Konfigurationsänderung',
    configuration_change: 'Konfigurationsänderung',
    role_change: 'Rollenänderung',
  };
  return labels[type] || type || '-';
}

function RequestDetails({ request }: { request: ApprovalRequest }) {
  const isConfigChange = request.requestType === 'configuration_change' || request.requestType === 'config_change';

  if (isConfigChange && request.metadata) {
    const paramName = request.metadata.parameterName as string;
    return (
      <div className="text-sm space-y-1">
        <p className="font-medium text-gray-900">{getParamDisplayName(paramName)}</p>
        <div className="flex items-center gap-2">
          <span className="text-gray-500">
            {formatConfigValue(paramName, request.metadata.oldValue)}
          </span>
          <svg className="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
          </svg>
          <span className="font-semibold text-fin1-primary">
            {formatConfigValue(paramName, request.metadata.newValue)}
          </span>
        </div>
        {typeof request.metadata.reason === 'string' && request.metadata.reason && (
          <p className="text-gray-500 text-xs truncate max-w-xs">Grund: {request.metadata.reason}</p>
        )}
      </div>
    );
  }

  return (
    <p className="text-sm text-gray-600 truncate max-w-xs">
      {(typeof request.metadata?.reason === 'string' ? request.metadata.reason : null) || '-'}
    </p>
  );
}

export function ApprovalsListPage() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [selectedRequest, setSelectedRequest] = useState<ApprovalRequest | null>(null);
  const [actionType, setActionType] = useState<'approve' | 'reject' | null>(null);
  const [withdrawTarget, setWithdrawTarget] = useState<ApprovalRequest | null>(null);
  const [notes, setNotes] = useState('');
  const [activeTab, setActiveTab] = useState<TabId>('pending');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['pendingApprovals'],
    queryFn: () => cloudFunction<ApprovalsResponse>('getPendingApprovals'),
    refetchInterval: 30000,
  });

  const approveMutation = useMutation({
    mutationFn: ({ requestId, notes }: { requestId: string; notes?: string }) =>
      cloudFunction<{ success: boolean; requestType?: string; applied?: boolean; message?: string }>('approveRequest', { requestId, notes }),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      if (result?.applied) {
        queryClient.invalidateQueries({ queryKey: ['configuration'] });
        queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      }
      closeModal();
    },
  });

  const rejectMutation = useMutation({
    mutationFn: ({ requestId, reason }: { requestId: string; reason: string }) =>
      cloudFunction('rejectRequest', { requestId, reason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      closeModal();
    },
  });

  const withdrawMutation = useMutation({
    mutationFn: ({ requestId, reason }: { requestId: string; reason?: string }) =>
      cloudFunction('withdrawRequest', { requestId, reason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      setWithdrawTarget(null);
      setNotes('');
    },
  });

  const closeModal = () => {
    setSelectedRequest(null);
    setActionType(null);
    setNotes('');
  };

  const pendingCount = data?.requests?.length ?? 0;
  const ownCount = data?.ownPending?.length ?? 0;
  const allCount = data?.allRequests?.length ?? 0;
  const historyCount = data?.history?.length ?? 0;

  const tabs: { id: TabId; label: string; count: number; icon: string }[] = [
    { id: 'pending', label: 'Freigaben erteilen', count: pendingCount, icon: '🔔' },
    { id: 'own', label: 'Eigene Anträge', count: ownCount, icon: '📝' },
    { id: 'all', label: 'Alle Anträge', count: allCount, icon: '📋' },
    { id: 'history', label: 'Abgeschlossen', count: historyCount, icon: '✅' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold">4-Augen-Prinzip — Anträge & Freigaben</h2>
            <p className="text-sm text-gray-500 mt-1">
              Übersicht aller Änderungsanträge mit 4-Augen-Freigabe
            </p>
          </div>
          <Button variant="secondary" onClick={() => refetch()}>
            Aktualisieren
          </Button>
        </div>
      </Card>

      {/* Tab Navigation */}
      <div className="flex border-b border-gray-200 overflow-x-auto">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
              activeTab === tab.id
                ? 'border-fin1-primary text-fin1-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            <span>{tab.icon}</span>
            <span>{tab.label}</span>
            {tab.count > 0 && (
              <span className={`ml-1 px-2 py-0.5 text-xs font-semibold rounded-full ${
                activeTab === tab.id
                  ? 'bg-fin1-primary text-white'
                  : tab.id === 'pending' && tab.count > 0
                    ? 'bg-amber-100 text-amber-800'
                    : 'bg-gray-100 text-gray-600'
              }`}>
                {tab.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Content */}
      {isLoading ? (
        <Card>
          <div className="p-8 text-center">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className="text-gray-500 mt-4">Laden...</p>
          </div>
        </Card>
      ) : error ? (
        <Card>
          <div className="p-8 text-center">
            <p className="text-red-500">Fehler beim Laden der Anfragen</p>
            <Button variant="secondary" className="mt-4" onClick={() => refetch()}>
              Erneut versuchen
            </Button>
          </div>
        </Card>
      ) : (
        <>
          {/* Tab: Pending Approvals (from other admins) */}
          {activeTab === 'pending' && (
            <Card padding="none">
              {pendingCount === 0 ? (
                <EmptyState
                  icon="check-circle"
                  message="Keine ausstehenden Freigaben"
                  description="Alle Anträge anderer Admins wurden bereits bearbeitet."
                />
              ) : (
                <RequestTable
                  requests={data!.requests}
                  showActions
                  onApprove={(r) => { setSelectedRequest(r); setActionType('approve'); }}
                  onReject={(r) => { setSelectedRequest(r); setActionType('reject'); }}
                  currentUserId={user?.objectId}
                />
              )}
            </Card>
          )}

          {/* Tab: Own Pending Requests */}
          {activeTab === 'own' && (
            <Card padding="none">
              {ownCount === 0 ? (
                <EmptyState
                  icon="document"
                  message="Keine eigenen offenen Anträge"
                  description="Sie haben aktuell keine Änderungen beantragt, die auf Freigabe warten."
                />
              ) : (
                <RequestTable
                  requests={data!.ownPending}
                  showStatus
                  showWithdraw
                  onWithdraw={(r) => setWithdrawTarget(r)}
                  currentUserId={user?.objectId}
                />
              )}
            </Card>
          )}

          {/* Tab: All Requests */}
          {activeTab === 'all' && (
            <Card padding="none">
              {allCount === 0 ? (
                <EmptyState
                  icon="archive"
                  message="Noch keine Anträge vorhanden"
                  description="Alle Anträge aller Admins erscheinen hier chronologisch."
                />
              ) : (
                <RequestTable
                  requests={data!.allRequests}
                  showStatus
                  showDecision
                  showWithdraw
                  onWithdraw={(r) => setWithdrawTarget(r)}
                  currentUserId={user?.objectId}
                />
              )}
            </Card>
          )}

          {/* Tab: History */}
          {activeTab === 'history' && (
            <Card padding="none">
              {historyCount === 0 ? (
                <EmptyState
                  icon="archive"
                  message="Noch keine abgeschlossenen Anträge"
                  description="Genehmigte und abgelehnte Anträge der letzten 30 Tage erscheinen hier."
                />
              ) : (
                <RequestTable
                  requests={data!.history}
                  showStatus
                  showDecision
                  currentUserId={user?.objectId}
                />
              )}
            </Card>
          )}
        </>
      )}

      {/* Approve / Reject Modal */}
      {selectedRequest && actionType && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg">
            <h3 className="text-lg font-semibold mb-4">
              {actionType === 'approve' ? 'Anfrage genehmigen' : 'Anfrage ablehnen'}
            </h3>

            <div className="space-y-3 mb-4 p-4 bg-gray-50 rounded-lg">
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">Typ:</span>
                <span className="text-sm font-medium">
                  {getRequestTypeLabel(selectedRequest.requestType)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">Beantragt von:</span>
                <span className="text-sm">
                  {selectedRequest.requesterEmail || selectedRequest.requesterId}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">Beantragt am:</span>
                <span className="text-sm">
                  {formatDateTime(selectedRequest.createdAt)}
                </span>
              </div>

              {(selectedRequest.requestType === 'configuration_change' || selectedRequest.requestType === 'config_change') && selectedRequest.metadata && (
                <div className="mt-3 p-3 bg-white border border-gray-200 rounded-lg">
                  <p className="text-sm font-medium text-gray-700 mb-2">
                    {getParamDisplayName(selectedRequest.metadata.parameterName as string)}
                  </p>
                  <div className="flex items-center gap-4 justify-center">
                    <div className="text-center">
                      <p className="text-xs text-gray-500 mb-1">Aktuell</p>
                      <p className="text-base font-semibold text-gray-700">
                        {formatConfigValue(selectedRequest.metadata.parameterName as string, selectedRequest.metadata.oldValue)}
                      </p>
                    </div>
                    <svg className="w-6 h-6 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                    </svg>
                    <div className="text-center">
                      <p className="text-xs text-gray-500 mb-1">Neuer Wert</p>
                      <p className="text-base font-semibold text-fin1-primary">
                        {formatConfigValue(selectedRequest.metadata.parameterName as string, selectedRequest.metadata.newValue)}
                      </p>
                    </div>
                  </div>
                </div>
              )}
              {typeof selectedRequest.metadata?.reason === 'string' && selectedRequest.metadata.reason && (
                <div className="mt-2">
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

      {/* Withdraw Confirmation Modal */}
      {withdrawTarget && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg">
            <h3 className="text-lg font-semibold mb-4">Antrag zurückziehen</h3>

            <div className="space-y-3 mb-4 p-4 bg-gray-50 rounded-lg">
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">Typ:</span>
                <span className="text-sm font-medium">
                  {getRequestTypeLabel(withdrawTarget.requestType)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-500">Beantragt am:</span>
                <span className="text-sm">{formatDateTime(withdrawTarget.createdAt)}</span>
              </div>
              {(withdrawTarget.requestType === 'configuration_change' || withdrawTarget.requestType === 'config_change') && withdrawTarget.metadata && (
                <div className="mt-2 p-3 bg-white border border-gray-200 rounded-lg">
                  <p className="text-sm font-medium text-gray-700 mb-1">
                    {getParamDisplayName(withdrawTarget.metadata.parameterName as string)}
                  </p>
                  <p className="text-sm text-gray-600">
                    {formatConfigValue(withdrawTarget.metadata.parameterName as string, withdrawTarget.metadata.oldValue)}
                    {' → '}
                    <span className="font-semibold">
                      {formatConfigValue(withdrawTarget.metadata.parameterName as string, withdrawTarget.metadata.newValue)}
                    </span>
                  </p>
                </div>
              )}
            </div>

            <p className="text-sm text-gray-600 mb-3">
              Möchten Sie diesen Antrag wirklich zurückziehen? Diese Aktion kann nicht rückgängig gemacht werden.
            </p>

            <label className="block text-sm font-medium text-gray-700 mb-1">
              Grund (optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4"
              rows={2}
              placeholder="Grund für das Zurückziehen..."
            />

            <div className="flex gap-3 justify-end">
              <Button variant="secondary" onClick={() => { setWithdrawTarget(null); setNotes(''); }}>
                Abbrechen
              </Button>
              <Button
                variant="danger"
                loading={withdrawMutation.isPending}
                onClick={() => {
                  withdrawMutation.mutate({
                    requestId: withdrawTarget.objectId,
                    reason: notes || undefined,
                  });
                }}
              >
                Zurückziehen
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

// ─── Sub-Components ──────────────────────────────────────────────────

function EmptyState({ icon, message, description }: { icon: string; message: string; description: string }) {
  const icons: Record<string, JSX.Element> = {
    'check-circle': (
      <svg className="w-12 h-12 text-green-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    'document': (
      <svg className="w-12 h-12 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
    ),
    'archive': (
      <svg className="w-12 h-12 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
      </svg>
    ),
  };

  return (
    <div className="p-8 text-center">
      {icons[icon]}
      <p className="text-gray-600 font-medium">{message}</p>
      <p className="text-gray-400 text-sm mt-1">{description}</p>
    </div>
  );
}

interface RequestTableProps {
  requests: ApprovalRequest[];
  showActions?: boolean;
  showStatus?: boolean;
  showDecision?: boolean;
  showWithdraw?: boolean;
  onApprove?: (r: ApprovalRequest) => void;
  onReject?: (r: ApprovalRequest) => void;
  onWithdraw?: (r: ApprovalRequest) => void;
  currentUserId?: string;
}

/** Normalize requesterId to string (handles Parse Pointer shape from API). */
function requesterIdString(r: ApprovalRequest): string {
  const id = r.requesterId;
  if (typeof id === 'string') return id;
  if (id && typeof id === 'object' && 'objectId' in id) return (id as { objectId: string }).objectId;
  return String(id ?? '');
}

function RequestTable({
  requests, showActions, showStatus, showDecision, showWithdraw,
  onApprove, onReject, onWithdraw, currentUserId,
}: RequestTableProps) {
  const hasActionColumn = showActions || showWithdraw;

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead className="bg-gray-50 border-b border-gray-200">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Typ</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Beantragt von</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Datum</th>
            {showStatus && (
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
            )}
            {showDecision && (
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Entscheidung</th>
            )}
            {hasActionColumn && (
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Aktionen</th>
            )}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200">
          {requests.map((request) => {
            const isOwn = currentUserId != null && requesterIdString(request) === currentUserId;
            const canWithdraw = showWithdraw && isOwn && request.status === 'pending';
            const canApproveReject = showActions && !isOwn;

            return (
              <tr key={request.objectId} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="text-sm font-medium text-gray-900">
                    {getRequestTypeLabel(request.requestType)}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <p className="text-sm text-gray-900">
                    {request.requesterEmail || requesterIdString(request)}
                    {isOwn && <span className="ml-1 text-xs text-gray-400">(Sie)</span>}
                  </p>
                  <p className="text-xs text-gray-500">{request.requesterRole}</p>
                </td>
                <td className="px-6 py-4">
                  <RequestDetails request={request} />
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <p className="text-sm text-gray-900">{formatDateTime(request.createdAt)}</p>
                  <p className="text-xs text-gray-500">{formatRelative(request.createdAt)}</p>
                </td>
                {showStatus && (
                  <td className="px-6 py-4 whitespace-nowrap">
                    {getStatusBadge(request.status)}
                  </td>
                )}
                {showDecision && (
                  <td className="px-6 py-4">
                    <div className="text-sm">
                      {request.approverEmail && (
                        <p className="text-gray-600">{request.approverEmail}</p>
                      )}
                      {request.approverNotes && (
                        <p className="text-xs text-gray-500 truncate max-w-xs">{request.approverNotes}</p>
                      )}
                      {request.rejectionReason && (
                        <p className="text-xs text-red-600 truncate max-w-xs">{request.rejectionReason}</p>
                      )}
                      {request.withdrawnReason && (
                        <p className="text-xs text-blue-600 truncate max-w-xs">{request.withdrawnReason}</p>
                      )}
                      {request.updatedAt && request.status !== 'pending' && (
                        <p className="text-xs text-gray-400">{formatDateTime(request.updatedAt)}</p>
                      )}
                    </div>
                  </td>
                )}
                {hasActionColumn && (
                  <td className="px-6 py-4 whitespace-nowrap text-right">
                    <div className="flex gap-2 justify-end">
                      {canApproveReject && (
                        <>
                          <Button variant="success" size="sm" onClick={() => onApprove?.(request)}>
                            Genehmigen
                          </Button>
                          <Button variant="danger" size="sm" onClick={() => onReject?.(request)}>
                            Ablehnen
                          </Button>
                        </>
                      )}
                      {canWithdraw && (
                        <Button variant="secondary" size="sm" onClick={() => onWithdraw?.(request)}>
                          Zurückziehen
                        </Button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
