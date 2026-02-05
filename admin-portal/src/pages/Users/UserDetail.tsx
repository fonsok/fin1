import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getUserDetails, updateUserStatus, forcePasswordReset } from '../../api/admin';
import type { TradeItem, TradeInvestor, InvestmentItem, ActivityItem } from '../../api/admin';
import { usePermissions } from '../../hooks/usePermissions';
import { Card, CardHeader, Button, Badge, getStatusVariant } from '../../components/ui';
import { formatDateTime, formatCurrency, getRoleDisplay, getStatusDisplay } from '../../utils/format';

export function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const perms = usePermissions();

  const [actionReason, setActionReason] = useState('');
  const [showActionModal, setShowActionModal] = useState<'suspend' | 'reactivate' | 'reset' | null>(null);

  const { data, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => getUserDetails(userId!),
    enabled: !!userId,
  });

  const user = data?.user;
  const wallet = data?.wallet;
  const tradeSummary = data?.tradeSummary;
  const trades = data?.trades || [];
  const investmentSummary = data?.investmentSummary;
  const investments = data?.investments || [];
  const recentActivity = data?.recentActivity || [];

  const statusMutation = useMutation({
    mutationFn: ({ status, reason }: { status: string; reason: string }) =>
      updateUserStatus(userId!, status, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', userId] });
      queryClient.invalidateQueries({ queryKey: ['users'] });
      setShowActionModal(null);
      setActionReason('');
    },
  });

  const resetMutation = useMutation({
    mutationFn: (reason: string) => forcePasswordReset(userId!, reason),
    onSuccess: () => {
      setShowActionModal(null);
      setActionReason('');
    },
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  if (error || !user) {
    return (
      <Card className="text-center py-8">
        <p className="text-red-500">Benutzer nicht gefunden</p>
        <Button variant="secondary" className="mt-4" onClick={() => navigate('/users')}>
          Zurück zur Liste
        </Button>
      </Card>
    );
  }

  const canSuspend = perms.canEditUserStatus && user.status === 'active';
  const canReactivate = perms.canEditUserStatus && ['suspended', 'locked'].includes(user.status);
  const canResetPassword = perms.canResetPasswords;

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => navigate('/users')}
        className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Zurück zur Benutzerliste
      </button>

      {/* User Header */}
      <Card>
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-fin1-light rounded-full flex items-center justify-center">
              <span className="text-2xl font-bold text-fin1-primary">
                {user.firstName?.[0] || user.email?.[0]?.toUpperCase() || '?'}
              </span>
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-900">
                {user.firstName && user.lastName
                  ? `${user.firstName} ${user.lastName}`
                  : user.username || user.email}
              </h2>
              <p className="text-gray-500">{user.email}</p>
              <div className="flex gap-2 mt-2">
                <Badge variant={getStatusVariant(user.status)}>
                  {getStatusDisplay(user.status)}
                </Badge>
                <Badge variant="neutral">
                  {getRoleDisplay(user.role)}
                </Badge>
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-2">
            {canResetPassword && (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setShowActionModal('reset')}
              >
                Passwort zurücksetzen
              </Button>
            )}
            {canSuspend && (
              <Button
                variant="danger"
                size="sm"
                onClick={() => setShowActionModal('suspend')}
              >
                Sperren
              </Button>
            )}
            {canReactivate && (
              <Button
                variant="success"
                size="sm"
                onClick={() => setShowActionModal('reactivate')}
              >
                Reaktivieren
              </Button>
            )}
          </div>
        </div>
      </Card>

      {/* User Details Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Basic Info */}
        <Card>
          <CardHeader title="Benutzerdaten" />
          <dl className="space-y-4">
            <DetailRow label="Kunden-ID" value={user.customerId || '-'} mono />
            <DetailRow label="E-Mail" value={user.email} />
            <DetailRow label="Benutzername" value={user.username || '-'} />
            <DetailRow label="Vorname" value={user.firstName || '-'} />
            <DetailRow label="Nachname" value={user.lastName || '-'} />
            <DetailRow label="Rolle" value={getRoleDisplay(user.role)} />
          </dl>
        </Card>

        {/* Status Info */}
        <Card>
          <CardHeader title="Status & Verifizierung" />
          <dl className="space-y-4">
            <DetailRow label="Account-Status" value={getStatusDisplay(user.status)} />
            <DetailRow label="KYC-Status" value={getStatusDisplay(user.kycStatus)} />
            <DetailRow label="Registriert" value={user.createdAt ? formatDateTime(user.createdAt) : '-'} />
            <DetailRow label="Letzte Änderung" value={user.updatedAt ? formatDateTime(user.updatedAt) : '-'} />
            <DetailRow label="Letzter Login" value={user.lastLoginAt ? formatDateTime(user.lastLoginAt) : 'Noch nie'} />
          </dl>
        </Card>
      </div>

      {/* Wallet/Balance Section */}
      {wallet && (
        <Card>
          <CardHeader title="Kontostand" />
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <p className="text-sm text-gray-500">Aktueller Saldo</p>
              <p className="text-2xl font-bold text-green-600">{formatCurrency(wallet.balance)}</p>
            </div>
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-500">Währung</p>
              <p className="text-2xl font-bold text-gray-700">{wallet.currency}</p>
            </div>
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-500">Letzte Aktualisierung</p>
              <p className="text-lg font-medium text-gray-700">
                {wallet.lastUpdated ? formatDateTime(wallet.lastUpdated) : '-'}
              </p>
            </div>
          </div>
        </Card>
      )}

      {/* Trader Section */}
      {tradeSummary && (
        <Card>
          <CardHeader title="Trading-Übersicht" />
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
            <StatBox label="Gesamt-Trades" value={tradeSummary.totalTrades.toString()} />
            <StatBox label="Abgeschlossen" value={tradeSummary.completedTrades.toString()} color="green" />
            <StatBox label="Aktiv" value={tradeSummary.activeTrades.toString()} color="blue" />
            <StatBox label="Gesamt-Gewinn" value={formatCurrency(tradeSummary.totalProfit)} color="green" />
            <StatBox label="Provision" value={formatCurrency(tradeSummary.totalCommission)} />
          </div>

          {trades.length > 0 && (
            <>
              <h4 className="font-medium text-gray-700 mb-3">Letzte Trades (mit Investoren)</h4>
              <div className="space-y-4">
                {trades.map((trade: TradeItem) => (
                  <TradeCard key={trade.objectId} trade={trade} />
                ))}
              </div>
            </>
          )}
        </Card>
      )}

      {/* Investor Section */}
      {investmentSummary && (
        <Card>
          <CardHeader title="Investment-Übersicht" />
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
            <StatBox label="Gesamt-Investments" value={investmentSummary.totalInvestments.toString()} />
            <StatBox label="Aktiv" value={investmentSummary.activeInvestments.toString()} color="blue" />
            <StatBox label="Investiert" value={formatCurrency(investmentSummary.totalInvested)} />
            <StatBox label="Gewinn" value={formatCurrency(investmentSummary.totalProfit)} color="green" />
            <StatBox label="Aktueller Wert" value={formatCurrency(investmentSummary.currentValue)} color="blue" />
          </div>

          {investments.length > 0 && (
            <>
              <h4 className="font-medium text-gray-700 mb-3">Letzte Investments</h4>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-2 text-left">Trader</th>
                      <th className="px-4 py-2 text-left">Status</th>
                      <th className="px-4 py-2 text-right">Betrag</th>
                      <th className="px-4 py-2 text-right">Gewinn</th>
                      <th className="px-4 py-2 text-left">Datum</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {investments.map((inv: InvestmentItem) => (
                      <tr key={inv.objectId} className="hover:bg-gray-50">
                        <td className="px-4 py-2">{inv.traderId}</td>
                        <td className="px-4 py-2">
                          <Badge variant={getStatusVariant(inv.status)}>
                            {getStatusDisplay(inv.status)}
                          </Badge>
                        </td>
                        <td className="px-4 py-2 text-right">{formatCurrency(inv.amount)}</td>
                        <td className={`px-4 py-2 text-right font-medium ${(inv.profit || 0) >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                          {formatCurrency(inv.profit || 0)}
                        </td>
                        <td className="px-4 py-2 text-gray-500">{formatDateTime(inv.createdAt)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </Card>
      )}

      {/* Activity Log */}
      {recentActivity.length > 0 && (
        <Card>
          <CardHeader title="Letzte Aktivitäten" />
          <div className="space-y-3">
            {recentActivity.map((activity: ActivityItem, index: number) => (
              <div key={index} className="flex items-center gap-4 p-3 bg-gray-50 rounded-lg">
                <div className="w-2 h-2 bg-fin1-primary rounded-full" />
                <div className="flex-1">
                  <p className="text-sm font-medium text-gray-900">{activity.description || activity.action}</p>
                  <p className="text-xs text-gray-500">{formatDateTime(activity.createdAt)}</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Action Modal */}
      {showActionModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h3 className="text-lg font-semibold mb-4">
              {showActionModal === 'suspend' && 'Benutzer sperren'}
              {showActionModal === 'reactivate' && 'Benutzer reaktivieren'}
              {showActionModal === 'reset' && 'Passwort zurücksetzen'}
            </h3>

            <p className="text-gray-600 mb-4">
              {showActionModal === 'suspend' && 'Der Benutzer wird gesperrt und kann sich nicht mehr anmelden.'}
              {showActionModal === 'reactivate' && 'Der Benutzer wird reaktiviert und kann sich wieder anmelden.'}
              {showActionModal === 'reset' && 'Der Benutzer muss beim nächsten Login ein neues Passwort setzen.'}
            </p>

            <label className="block text-sm font-medium text-gray-700 mb-1">
              Begründung (wird protokolliert)
            </label>
            <textarea
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary mb-4"
              rows={3}
              placeholder="Grund für diese Aktion..."
              required
            />

            <div className="flex gap-3 justify-end">
              <Button
                variant="secondary"
                onClick={() => {
                  setShowActionModal(null);
                  setActionReason('');
                }}
              >
                Abbrechen
              </Button>
              <Button
                variant={showActionModal === 'suspend' ? 'danger' : 'primary'}
                disabled={!actionReason.trim()}
                loading={statusMutation.isPending || resetMutation.isPending}
                onClick={() => {
                  if (showActionModal === 'suspend') {
                    statusMutation.mutate({ status: 'suspended', reason: actionReason });
                  } else if (showActionModal === 'reactivate') {
                    statusMutation.mutate({ status: 'active', reason: actionReason });
                  } else if (showActionModal === 'reset') {
                    resetMutation.mutate(actionReason);
                  }
                }}
              >
                Bestätigen
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

function DetailRow({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex justify-between">
      <dt className="text-sm text-gray-500">{label}</dt>
      <dd className={`text-sm text-gray-900 ${mono ? 'font-mono' : ''}`}>{value}</dd>
    </div>
  );
}

function StatBox({
  label,
  value,
  color = 'gray',
}: {
  label: string;
  value: string;
  color?: 'gray' | 'green' | 'blue' | 'red';
}) {
  const colorClasses = {
    gray: 'bg-gray-50 text-gray-700',
    green: 'bg-green-50 text-green-700',
    blue: 'bg-blue-50 text-blue-700',
    red: 'bg-red-50 text-red-700',
  };

  return (
    <div className={`text-center p-3 rounded-lg ${colorClasses[color]}`}>
      <p className="text-xs text-gray-500">{label}</p>
      <p className="text-lg font-bold">{value}</p>
    </div>
  );
}

function TradeCard({ trade }: { trade: TradeItem }) {
  const [expanded, setExpanded] = useState(false);
  const hasInvestors = trade.investors && trade.investors.length > 0;

  return (
    <div className="border rounded-lg overflow-hidden">
      {/* Trade Header */}
      <div
        className={`p-4 bg-white flex items-center justify-between ${hasInvestors ? 'cursor-pointer hover:bg-gray-50' : ''}`}
        onClick={() => hasInvestors && setExpanded(!expanded)}
      >
        <div className="flex items-center gap-4">
          <span className="font-mono font-bold text-fin1-primary">#{trade.tradeNumber}</span>
          <div>
            <p className="font-medium">{trade.symbol}</p>
            <p className="text-sm text-gray-500">{trade.description}</p>
          </div>
        </div>
        <div className="flex items-center gap-6">
          <div className="text-right">
            <p className={`font-bold ${(trade.grossProfit || 0) >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              {formatCurrency(trade.grossProfit || 0)}
            </p>
            <p className="text-xs text-gray-500">Brutto-Gewinn</p>
          </div>
          <Badge variant={getStatusVariant(trade.status)}>
            {getStatusDisplay(trade.status)}
          </Badge>
          {hasInvestors && (
            <div className="flex items-center gap-1 text-gray-400">
              <span className="text-sm">{trade.investors?.length} Investor{trade.investors?.length !== 1 ? 'en' : ''}</span>
              <svg
                className={`w-5 h-5 transition-transform ${expanded ? 'rotate-180' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          )}
        </div>
      </div>

      {/* Trade Details */}
      <div className="px-4 pb-2 bg-gray-50 text-xs text-gray-500 flex gap-4">
        <span>Erstellt: {formatDateTime(trade.createdAt)}</span>
        {trade.completedAt && <span>Abgeschlossen: {formatDateTime(trade.completedAt)}</span>}
        {trade.totalFees !== undefined && <span>Provision: {formatCurrency(trade.totalFees)}</span>}
      </div>

      {/* Investors Section */}
      {expanded && hasInvestors && (
        <div className="border-t bg-blue-50 p-4">
          <h5 className="font-medium text-sm text-gray-700 mb-3">Beteiligte Investoren</h5>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-blue-100">
                <tr>
                  <th className="px-3 py-2 text-left">Investor</th>
                  <th className="px-3 py-2 text-right">Anteil</th>
                  <th className="px-3 py-2 text-right">Investiert</th>
                  <th className="px-3 py-2 text-right">Gewinn-Anteil</th>
                  <th className="px-3 py-2 text-right">Provision</th>
                  <th className="px-3 py-2 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-blue-100">
                {trade.investors?.map((inv: TradeInvestor, idx: number) => (
                  <tr key={idx} className="bg-white">
                    <td className="px-3 py-2">
                      <p className="font-medium">{inv.investorName}</p>
                      <p className="text-xs text-gray-500">{inv.investorEmail}</p>
                    </td>
                    <td className="px-3 py-2 text-right font-mono">
                      {(inv.ownershipPercentage || 0).toFixed(1)}%
                    </td>
                    <td className="px-3 py-2 text-right">
                      {formatCurrency(inv.investedAmount || 0)}
                    </td>
                    <td className={`px-3 py-2 text-right font-medium ${(inv.profitShare || 0) >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                      {formatCurrency(inv.profitShare || 0)}
                    </td>
                    <td className="px-3 py-2 text-right text-gray-600">
                      {formatCurrency(inv.commissionAmount || 0)}
                    </td>
                    <td className="px-3 py-2 text-center">
                      <Badge variant={inv.isSettled ? 'success' : 'warning'}>
                        {inv.isSettled ? 'Abgerechnet' : 'Offen'}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
