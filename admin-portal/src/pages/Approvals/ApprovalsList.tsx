import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { cloudFunction } from '../../api/admin';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import { Card, Button, Badge, PaginationBar } from '../../components/ui';
import { formatCurrency, formatPercentage } from '../../utils/format';
import { ApprovalsTabs } from './components/ApprovalsTabs';
import { ApprovalDecisionModal } from './components/ApprovalDecisionModal';
import { WithdrawRequestModal } from './components/WithdrawRequestModal';
import { ApprovalsEmptyState } from './components/ApprovalsEmptyState';
import { ApprovalsRequestTable } from './components/ApprovalsRequestTable';

import { adminCaption, adminLabel, adminMuted, adminPrimary, adminSoft } from '../../utils/adminThemeClasses';
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
  appServiceChargeRate: 'percentage',
  initialAccountBalance: 'currency',
  minimumCashReserve: 'currency',
  minInvestment: 'currency',
  maxInvestment: 'currency',
  poolBalanceDistributionThreshold: 'currency',
  daily_transaction_limit: 'currency',
  weekly_transaction_limit: 'currency',
  monthly_transaction_limit: 'currency',
};

const PARAM_DISPLAY_NAMES: Record<string, string> = {
  traderCommissionRate: 'Trader-Provision',
  appServiceChargeRate: 'App-Servicegebühr',
  initialAccountBalance: 'Startguthaben',
  minimumCashReserve: 'Mindest-Bargeldreserve',
  minInvestment: 'Mindestinvestmentbetrag',
  maxInvestment: 'Maximuminvestmentbetrag',
  poolBalanceDistributionThreshold: 'Pool-Verteilungsschwelle',
  daily_transaction_limit: 'Tages-Transaktionslimit',
  weekly_transaction_limit: 'Wochen-Transaktionslimit',
  monthly_transaction_limit: 'Monats-Transaktionslimit',
  walletFeatureEnabled: 'Ein-/Auszahlungen erlaubt',
  walletActionMode: 'Konto-Aktionsmodus',
  walletActionModeGlobal: 'Konto-Aktionsmodus (Global)',
  walletActionModeInvestor: 'Konto-Aktionsmodus (Investor)',
  walletActionModeTrader: 'Konto-Aktionsmodus (Trader)',
  walletActionModeIndividual: 'Konto-Aktionsmodus (Privatperson)',
  walletActionModeCompany: 'Konto-Aktionsmodus (Company)',
  walletActionModeOverride: 'Nutzer-Konto-Aktionsmodus',
  serviceChargeInvoiceFromBackend: 'Servicegebühr-Rechnung über Server',
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
    user_wallet_action_mode_change: 'Nutzer-Konto-Sperre',
  };
  return labels[type] || type || '-';
}

function RequestDetails({ request }: { request: ApprovalRequest }) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const isConfigChange = request.requestType === 'configuration_change' || request.requestType === 'config_change';

  if (isConfigChange && request.metadata) {
    const paramName = request.metadata.parameterName as string;
    return (
      <div className="text-sm space-y-1">
        <p className={clsx('font-medium', adminPrimary(isDark))}>
          {getParamDisplayName(paramName)}
        </p>
        <div className="flex items-center gap-2">
          <span className={clsx(adminMuted(isDark))}>
            {formatConfigValue(paramName, request.metadata.oldValue)}
          </span>
          <svg
            className={clsx('w-4 h-4 flex-shrink-0', adminCaption(isDark))}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
          </svg>
          <span className="font-semibold text-fin1-primary">
            {formatConfigValue(paramName, request.metadata.newValue)}
          </span>
        </div>
        {typeof request.metadata.reason === 'string' && request.metadata.reason && (
          <p className={clsx('text-xs truncate max-w-xs', adminMuted(isDark))}>
            Grund: {request.metadata.reason}
          </p>
        )}
      </div>
    );
  }

  if (request.requestType === 'user_wallet_action_mode_change' && request.metadata) {
    return (
      <div className="text-sm space-y-1">
        <p className={clsx('font-medium', adminPrimary(isDark))}>
          Nutzer: {String(request.metadata.targetUserEmail || request.metadata.targetUserId || '-')}
        </p>
        <div className="flex items-center gap-2">
          <span className={clsx(adminMuted(isDark))}>
            {String(request.metadata.oldMode ?? 'kein Override')}
          </span>
          <svg
            className={clsx('w-4 h-4 flex-shrink-0', adminCaption(isDark))}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
          </svg>
          <span className="font-semibold text-fin1-primary">{String(request.metadata.newMode ?? '-')}</span>
        </div>
        {typeof request.metadata.reason === 'string' && request.metadata.reason && (
          <p className={clsx('text-xs truncate max-w-xs', adminMuted(isDark))}>
            Grund: {request.metadata.reason}
          </p>
        )}
      </div>
    );
  }

  return (
    <p className={clsx('text-sm truncate max-w-xs', adminSoft(isDark))}>
      {(typeof request.metadata?.reason === 'string' ? request.metadata.reason : null) || '-'}
    </p>
  );
}

/** Match a single request against the active type filter. */
function matchesTypeFilter(r: ApprovalRequest, filter: string): boolean {
  if (!filter) return true;
  if (filter.startsWith('config:')) {
    const paramKey = filter.slice(7);
    const isConfig = r.requestType === 'configuration_change' || r.requestType === 'config_change';
    return isConfig && (r.metadata?.parameterName as string) === paramKey;
  }
  if (filter === 'configuration_change') {
    return r.requestType === 'configuration_change' || r.requestType === 'config_change';
  }
  return r.requestType === filter;
}

export function ApprovalsListPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();
  const [selectedRequest, setSelectedRequest] = useState<ApprovalRequest | null>(null);
  const [actionType, setActionType] = useState<'approve' | 'reject' | null>(null);
  const [withdrawTarget, setWithdrawTarget] = useState<ApprovalRequest | null>(null);
  const [notes, setNotes] = useState('');
  const [activeTab, setActiveTab] = useState<TabId>('pending');
  const [typeFilter, setTypeFilter] = useState('');
  const [pageByTab, setPageByTab] = useState<Record<TabId, number>>({
    pending: 0,
    own: 0,
    all: 0,
    history: 0,
  });
  const [pageSize, setPageSize] = useState(50);

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['pendingApprovals'],
    queryFn: () => cloudFunction<ApprovalsResponse>('getPendingApprovals'),
    refetchInterval: 30000,
  });

  const configParamOptions = useMemo(() => {
    if (!data) return [];
    const all = [...(data.requests ?? []), ...(data.ownPending ?? []), ...(data.allRequests ?? []), ...(data.history ?? [])];
    const seen = new Set<string>();
    for (const r of all) {
      if ((r.requestType === 'configuration_change' || r.requestType === 'config_change') && r.metadata?.parameterName) {
        seen.add(r.metadata.parameterName as string);
      }
    }
    return Array.from(seen).sort((a, b) =>
      (PARAM_DISPLAY_NAMES[a] ?? a).localeCompare(PARAM_DISPLAY_NAMES[b] ?? b, 'de'),
    );
  }, [data]);

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

  const filterList = (list: ApprovalRequest[]) =>
    typeFilter ? list.filter((r) => matchesTypeFilter(r, typeFilter)) : list;

  const pendingCount = filterList(data?.requests ?? []).length;
  const ownCount = filterList(data?.ownPending ?? []).length;
  const allCount = filterList(data?.allRequests ?? []).length;
  const historyCount = filterList(data?.history ?? []).length;

  const tabs: { id: TabId; label: string; count: number; icon: string }[] = [
    { id: 'pending', label: 'Freigaben erteilen', count: pendingCount, icon: '🔔' },
    { id: 'own', label: 'Eigene Anträge', count: ownCount, icon: '📝' },
    { id: 'all', label: 'Alle Anträge', count: allCount, icon: '📋' },
    { id: 'history', label: 'Abgeschlossen', count: historyCount, icon: '✅' },
  ];

  const tabRequests: Record<TabId, ApprovalRequest[]> = {
    pending: data?.requests ?? [],
    own: data?.ownPending ?? [],
    all: data?.allRequests ?? [],
    history: data?.history ?? [],
  };
  const activeRequests = typeFilter
    ? tabRequests[activeTab].filter((r) => matchesTypeFilter(r, typeFilter))
    : tabRequests[activeTab];
  const activePage = pageByTab[activeTab] ?? 0;
  const pagedActiveRequests = activeRequests.slice(activePage * pageSize, (activePage + 1) * pageSize);

  const setPageForActiveTab = (nextPage: number) => {
    setPageByTab((prev) => ({ ...prev, [activeTab]: nextPage }));
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h2 className={clsx('text-lg font-semibold', adminPrimary(isDark))}>
              4-Augen-Prinzip — Anträge & Freigaben
            </h2>
            <p className={clsx('text-sm mt-1', adminMuted(isDark))}>
              Übersicht aller Änderungsanträge mit 4-Augen-Freigabe
            </p>
          </div>
          <Button variant="secondary" onClick={() => refetch()}>
            Aktualisieren
          </Button>
        </div>
      </Card>

      <ApprovalsTabs
        activeTab={activeTab}
        tabs={tabs}
        onSelect={(tab) => {
          setActiveTab(tab);
          setPageByTab((prev) => ({ ...prev, [tab]: 0 }));
        }}
      />

      {/* Type filter */}
      <Card>
        <div className="flex flex-col sm:flex-row sm:items-center gap-3">
          <label className={clsx('text-sm font-medium', adminLabel(isDark))}>
            Typ filtern:
          </label>
          <select
            value={typeFilter}
            onChange={(e) => {
              setTypeFilter(e.target.value);
              setPageByTab((prev) => ({ ...prev, [activeTab]: 0 }));
            }}
            className={clsx(
              'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary text-sm',
              isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
            )}
          >
            <option value="">Alle Typen</option>
            <optgroup label="Antragsart">
              <option value="configuration_change">Konfigurationsänderung (alle)</option>
              <option value="correction">Korrekturbuchung</option>
              <option value="user_delete">Benutzer löschen</option>
              <option value="large_transaction">Große Transaktion</option>
              <option value="role_change">Rollenänderung</option>
            </optgroup>
            {configParamOptions.length > 0 && (
              <optgroup label="Konfigurationsparameter">
                {configParamOptions.map((key) => (
                  <option key={key} value={`config:${key}`}>
                    {PARAM_DISPLAY_NAMES[key] ?? key}
                  </option>
                ))}
              </optgroup>
            )}
          </select>
          {typeFilter && (
            <button
              type="button"
              onClick={() => {
                setTypeFilter('');
                setPageByTab((prev) => ({ ...prev, [activeTab]: 0 }));
              }}
              className="text-xs text-fin1-primary hover:underline"
            >
              Filter zurücksetzen
            </button>
          )}
        </div>
      </Card>

      {/* Content */}
      {isLoading ? (
        <Card>
          <div className="p-8 text-center">
            <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full mx-auto"></div>
            <p className={clsx('mt-4', adminMuted(isDark))}>Laden...</p>
          </div>
        </Card>
      ) : error ? (
        <Card>
          <div className="p-8 text-center">
            <p className={clsx(isDark ? 'text-red-300' : 'text-red-500')}>Fehler beim Laden der Anfragen</p>
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
                <ApprovalsEmptyState
                  icon="check-circle"
                  message="Keine ausstehenden Freigaben"
                  description="Alle Anträge anderer Admins wurden bereits bearbeitet."
                />
              ) : (
                <ApprovalsRequestTable
                  requests={pagedActiveRequests}
                  showActions
                  onApprove={(r) => { setSelectedRequest(r); setActionType('approve'); }}
                  onReject={(r) => { setSelectedRequest(r); setActionType('reject'); }}
                  currentUserId={user?.objectId}
                  getRequestTypeLabel={getRequestTypeLabel}
                  getStatusBadge={getStatusBadge}
                  renderRequestDetails={(request) => <RequestDetails request={request as ApprovalRequest} />}
                />
              )}
            </Card>
          )}

          {/* Tab: Own Pending Requests */}
          {activeTab === 'own' && (
            <Card padding="none">
              {ownCount === 0 ? (
                <ApprovalsEmptyState
                  icon="document"
                  message="Keine eigenen offenen Anträge"
                  description="Sie haben aktuell keine Änderungen beantragt, die auf Freigabe warten."
                />
              ) : (
                <ApprovalsRequestTable
                  requests={pagedActiveRequests}
                  showStatus
                  showWithdraw
                  onWithdraw={(r) => setWithdrawTarget(r)}
                  currentUserId={user?.objectId}
                  getRequestTypeLabel={getRequestTypeLabel}
                  getStatusBadge={getStatusBadge}
                  renderRequestDetails={(request) => <RequestDetails request={request as ApprovalRequest} />}
                />
              )}
            </Card>
          )}

          {/* Tab: All Requests */}
          {activeTab === 'all' && (
            <Card padding="none">
              {allCount === 0 ? (
                <ApprovalsEmptyState
                  icon="archive"
                  message="Noch keine Anträge vorhanden"
                  description="Alle Anträge aller Admins erscheinen hier chronologisch."
                />
              ) : (
                <ApprovalsRequestTable
                  requests={pagedActiveRequests}
                  showStatus
                  showDecision
                  showWithdraw
                  onWithdraw={(r) => setWithdrawTarget(r)}
                  currentUserId={user?.objectId}
                  getRequestTypeLabel={getRequestTypeLabel}
                  getStatusBadge={getStatusBadge}
                  renderRequestDetails={(request) => <RequestDetails request={request as ApprovalRequest} />}
                />
              )}
            </Card>
          )}

          {/* Tab: History */}
          {activeTab === 'history' && (
            <Card padding="none">
              {historyCount === 0 ? (
                <ApprovalsEmptyState
                  icon="archive"
                  message="Noch keine abgeschlossenen Anträge"
                  description="Genehmigte und abgelehnte Anträge der letzten 30 Tage erscheinen hier."
                />
              ) : (
                <ApprovalsRequestTable
                  requests={pagedActiveRequests}
                  showStatus
                  showDecision
                  currentUserId={user?.objectId}
                  getRequestTypeLabel={getRequestTypeLabel}
                  getStatusBadge={getStatusBadge}
                  renderRequestDetails={(request) => <RequestDetails request={request as ApprovalRequest} />}
                />
              )}
            </Card>
          )}
        </>
      )}

      {!isLoading && !error && activeRequests.length > 0 && (
        <Card>
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <select
              value={pageSize}
              onChange={(e) => {
                setPageSize(Number(e.target.value));
                setPageByTab((prev) => ({ ...prev, [activeTab]: 0 }));
              }}
              className={clsx(
                'px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary',
                isDark ? 'bg-slate-900/70 border-slate-600 text-slate-100' : 'bg-white border-gray-300 text-gray-900',
              )}
            >
              <option value={20}>20 / Seite</option>
              <option value={50}>50 / Seite</option>
              <option value={100}>100 / Seite</option>
            </select>
            <PaginationBar
              page={activePage}
              pageSize={pageSize}
              total={activeRequests.length}
              itemLabel="Einträgen"
              onPageChange={setPageForActiveTab}
            />
          </div>
        </Card>
      )}

      <ApprovalDecisionModal
        selectedRequest={selectedRequest}
        actionType={actionType}
        notes={notes}
        loading={approveMutation.isPending || rejectMutation.isPending}
        onChangeNotes={setNotes}
        onClose={closeModal}
        onConfirm={() => {
          if (!selectedRequest || !actionType) return;
          if (actionType === 'approve') {
            approveMutation.mutate({ requestId: selectedRequest.objectId, notes: notes || undefined });
          } else {
            rejectMutation.mutate({ requestId: selectedRequest.objectId, reason: notes });
          }
        }}
        getRequestTypeLabel={getRequestTypeLabel}
        getParamDisplayName={getParamDisplayName}
        formatConfigValue={formatConfigValue}
      />

      <WithdrawRequestModal
        withdrawTarget={withdrawTarget}
        notes={notes}
        loading={withdrawMutation.isPending}
        onChangeNotes={setNotes}
        onClose={() => { setWithdrawTarget(null); setNotes(''); }}
        onConfirm={() => {
          if (!withdrawTarget) return;
          withdrawMutation.mutate({
            requestId: withdrawTarget.objectId,
            reason: notes || undefined,
          });
        }}
        getRequestTypeLabel={getRequestTypeLabel}
        getParamDisplayName={getParamDisplayName}
        formatConfigValue={formatConfigValue}
      />
    </div>
  );
}

