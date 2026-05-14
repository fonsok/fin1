import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { getUserDetails, updateUserStatus, forcePasswordReset, requestUserWalletActionModeChange, logAdminCustomerView } from '../../api/admin';
import type { InvestmentItem, ActivityItem } from '../../api/admin';
import { usePermissions } from '../../hooks/usePermissions';
import { useAuth } from '../../context/AuthContext';
import { Card, CardHeader, Button, Badge, getStatusVariant } from '../../components/ui';
import { formatDateTime, formatCurrency, getRoleDisplay, getStatusDisplay } from '../../utils/format';
import { useTheme } from '../../context/ThemeContext';
import { UserTradeCard } from './components/UserTradeCard';
import { InvestmentTable } from './components/InvestmentTable';
import { AccountStatementCard } from './components/AccountStatementCard';
import { UserActionModal } from './components/UserActionModal';
import { DetailRow, StatBox } from './components/UserShared';

import { adminBackLink, adminControlField, adminHeadlineAlt, adminPrimary, adminPrimaryBrand, adminSoft, adminStatTitle, adminStrong } from '../../utils/adminThemeClasses';
export function UserDetailPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const perms = usePermissions();
  const { user: currentUser } = useAuth();

  const [actionReason, setActionReason] = useState('');
  const [showActionModal, setShowActionModal] = useState<'suspend' | 'reactivate' | 'reset' | null>(null);
  const [walletMode, setWalletMode] = useState<'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal'>('deposit_and_withdrawal');
  const [walletReason, setWalletReason] = useState('');
  const customerViewLoggedRef = useRef(false);

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
  const accountStatement = data?.accountStatement;
  const walletControls = data?.walletControls;
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

  const walletModeMutation = useMutation({
    mutationFn: ({ mode, reason }: { mode: 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal'; reason: string }) =>
      requestUserWalletActionModeChange(userId!, mode, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', userId] });
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      setWalletReason('');
    },
  });

  useEffect(() => {
    customerViewLoggedRef.current = false;
  }, [userId]);

  useEffect(() => {
    if (!userId || !data?.user) {
      return;
    }
    if (customerViewLoggedRef.current) {
      return;
    }
    customerViewLoggedRef.current = true;
    void logAdminCustomerView({
      targetUserId: userId,
      viewContext: 'user_detail_page',
    }).catch((err) => {
      console.warn('logAdminCustomerView:', err);
    });
  }, [userId, data?.user]);

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
        <p className={clsx(isDark ? 'text-red-400' : 'text-red-500')}>Benutzer nicht gefunden</p>
        <Button variant="secondary" className="mt-4" onClick={() => navigate('/users')}>
          Zurück zur Liste
        </Button>
      </Card>
    );
  }

  const isSelf = currentUser?.objectId === user.objectId;
  const canSuspend = perms.canEditUserStatus && user.status === 'active' && !isSelf;
  const canReactivate = perms.canEditUserStatus && ['suspended', 'locked'].includes(user.status);
  const canResetPassword = perms.canResetPasswords;

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => navigate('/users')}
        className={clsx('flex items-center gap-2', adminBackLink(isDark))}
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Zurück zur Benutzerliste
      </button>

      <div
        className={clsx(
          'rounded-lg border p-4',
          isDark ? 'border-sky-800/80 bg-sky-950/50' : 'border-sky-200 bg-sky-50',
        )}
        role="status"
      >
        <p className={clsx('text-sm font-semibold', isDark ? 'text-sky-100' : 'text-sky-950')}>
          Kundensicht (Lesemodus)
        </p>
        <p className={clsx('mt-2 text-xs leading-relaxed', isDark ? 'text-sky-200/90' : 'text-sky-900/85')}>
          Sie sehen die Daten dieses Nutzers im Admin Web Portal. Es gibt keine Anmeldung „als Kunde“; Ihre Sitzung
          bleibt die des eingeloggten Portal-Benutzers. Schreibende Aktionen laufen über die bestehenden Workflows
          und Berechtigungen. Der Aufruf dieser Seite wird zusätzlich als Eintrag vom Typ „admin_customer_view“
          protokolliert.
        </p>
      </div>

      {/* User Header */}
      <Card>
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div
              className={clsx(
                'w-16 h-16 rounded-full flex items-center justify-center',
                isDark ? 'bg-slate-800 border border-slate-600' : 'bg-fin1-light'
              )}
            >
              <span className={clsx('text-2xl font-bold', adminPrimaryBrand(isDark))}>
                {user.firstName?.[0] || user.email?.[0]?.toUpperCase() || '?'}
              </span>
            </div>
            <div>
              <h2 className={clsx('text-xl font-bold', adminPrimary(isDark))}>
                {user.firstName && user.lastName
                  ? `${user.firstName} ${user.lastName}`
                  : user.username || user.email}
              </h2>
              <p className={clsx(adminStatTitle(isDark))}>{user.email}</p>
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
        {isSelf && (
          <p className={clsx('text-xs mt-3', adminStatTitle(isDark))}>
            Eigene Sperrung ist aus Sicherheitsgründen deaktiviert.
          </p>
        )}
      </Card>

      {/* User Details Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Basic Info */}
        <Card>
          <CardHeader title="Benutzerdaten" />
          <dl className="space-y-4">
            <DetailRow label="Kundennummer" value={user.customerNumber || '-'} mono />
            <DetailRow label="Anrede" value={user.salutation === 'mr' ? 'Herr' : user.salutation === 'ms' ? 'Frau' : (user.salutation || '-')} />
            <DetailRow label="Vorname" value={user.firstName || '-'} />
            <DetailRow label="Nachname" value={user.lastName || '-'} />
            <DetailRow label="E-Mail" value={user.email} />
            <DetailRow label="Benutzername" value={user.username || '-'} />
            <DetailRow label="Telefon" value={user.phoneNumber || '-'} />
            <DetailRow label="Geburtsdatum" value={user.dateOfBirth || '-'} />
            <DetailRow label="Rolle" value={getRoleDisplay(user.role)} />
          </dl>
        </Card>

        {/* Address & Status */}
        <Card>
          <CardHeader title="Adresse & Status" />
          <dl className="space-y-4">
            <DetailRow label="Straße" value={user.streetAndNumber || '-'} />
            <DetailRow label="PLZ / Ort" value={user.postalCode && user.city ? `${user.postalCode} ${user.city}` : '-'} />
            <DetailRow label="Bundesland" value={user.state || '-'} />
            <DetailRow label="Land" value={user.country || '-'} />
            <DetailRow label="Nationalität" value={user.nationality || '-'} />
            <DetailRow label="Account-Status" value={getStatusDisplay(user.status)} />
            <DetailRow label="KYC-Status" value={getStatusDisplay(user.kycStatus)} />
            <DetailRow label="Registriert" value={user.createdAt ? formatDateTime(user.createdAt) : '-'} />
            <DetailRow label="Letzter Login" value={user.lastLoginAt ? formatDateTime(user.lastLoginAt) : 'Noch nie'} />
          </dl>
        </Card>
      </div>

      {/* Account/Balance Section */}
      {wallet && (
        <Card>
          <CardHeader title="Kontostand" />
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className={clsx('text-center p-4 rounded-lg', isDark ? 'bg-emerald-950/30 border border-emerald-700' : 'bg-green-50')}>
              <p className={clsx('text-sm', adminStatTitle(isDark))}>Aktueller Saldo</p>
              <p className={clsx('text-2xl font-bold', isDark ? 'text-emerald-400' : 'text-green-600')}>
                {formatCurrency(wallet.balance)}
              </p>
            </div>
            <div className={clsx('text-center p-4 rounded-lg', isDark ? 'bg-slate-900/60 border border-slate-700' : 'bg-gray-50')}>
              <p className={clsx('text-sm', adminStatTitle(isDark))}>Währung</p>
              <p className={clsx('text-2xl font-bold', adminHeadlineAlt(isDark))}>{wallet.currency}</p>
            </div>
            <div className={clsx('text-center p-4 rounded-lg', isDark ? 'bg-slate-900/60 border border-slate-700' : 'bg-gray-50')}>
              <p className={clsx('text-sm', adminStatTitle(isDark))}>Letzte Aktualisierung</p>
              <p className={clsx('text-lg font-medium', adminHeadlineAlt(isDark))}>
                {wallet.lastUpdated ? formatDateTime(wallet.lastUpdated) : '-'}
              </p>
            </div>
          </div>
        </Card>
      )}

      <Card>
        <CardHeader title="Nutzerbezogene Konto-Aktionssperre (4-Augen)" />
        <div className="space-y-3">
          <p className={clsx('text-sm', adminSoft(isDark))}>
            Effektiver Modus wird pro Nutzer aus der Schnittmenge berechnet: Global, Rolle (Investor/Trader),
            Account-Typ (Privatperson/Company) und optional Nutzer-Override. Dadurch gilt automatisch:
            Nutzer-Override kann nur weiter einschränken, nie erweitern.
          </p>
          <p className={clsx('text-sm', adminSoft(isDark))}>
            Aktueller Modus für diesen Nutzer:{' '}
            <span className={clsx('font-semibold', adminPrimary(isDark))}>
              {walletControls?.effectiveMode ?? 'deposit_and_withdrawal'}
            </span>
            {' '}| Nutzer-Override:{' '}
            <span className={clsx('font-semibold', adminPrimary(isDark))}>
              {walletControls?.userOverrideMode ?? 'kein Override'}
            </span>
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <select
              value={walletMode}
              onChange={(e) => setWalletMode(e.target.value as 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal')}
              className={clsx(
                'px-3 py-2 border rounded-lg',
                adminControlField(isDark),
              )}
            >
              <option value="disabled">Deaktiviert (beides gesperrt)</option>
              <option value="deposit_only">Nur Einzahlungen</option>
              <option value="withdrawal_only">Nur Auszahlungen</option>
              <option value="deposit_and_withdrawal">Ein- und Auszahlungen</option>
            </select>
            <input
              value={walletReason}
              onChange={(e) => setWalletReason(e.target.value)}
              placeholder="Begründung (Pflicht)"
              className={clsx(
                'px-3 py-2 border rounded-lg md:col-span-2',
                adminControlField(isDark),
              )}
            />
          </div>
          <div className="flex items-center gap-3">
            <Button
              size="sm"
              onClick={() => walletModeMutation.mutate({ mode: walletMode, reason: walletReason })}
              disabled={!walletReason.trim() || walletModeMutation.isPending}
            >
              Sperrung via 4-Augen beantragen
            </Button>
            {walletModeMutation.isSuccess && (
              <span className={clsx('text-sm', isDark ? 'text-emerald-400' : 'text-green-600')}>Antrag erstellt.</span>
            )}
            {walletModeMutation.isError && (
              <span className={clsx('text-sm', isDark ? 'text-red-400' : 'text-red-500')}>Antrag konnte nicht erstellt werden.</span>
            )}
          </div>
        </div>
      </Card>

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
              <h4 className={clsx('font-medium mb-3', adminStrong(isDark))}>Letzte Trades (mit Investoren)</h4>
              <div className="space-y-4">
                {trades.map((trade) => (
                  <UserTradeCard key={trade.objectId} trade={trade} />
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
          <div className="grid grid-cols-2 md:grid-cols-6 gap-4 mb-6">
            <StatBox label="Gesamt" value={investmentSummary.totalInvestments.toString()} />
            <StatBox label="Reserviert" value={(investmentSummary.reservedInvestments ?? 0).toString()} />
            <StatBox label="Aktiv" value={investmentSummary.activeInvestments.toString()} color="blue" />
            <StatBox label="Abgeschlossen" value={(investmentSummary.completedInvestments ?? 0).toString()} color="green" />
            <StatBox label="Investiert" value={formatCurrency(investmentSummary.totalInvested)} />
            <StatBox label="Gewinn" value={formatCurrency(investmentSummary.totalProfit)} color="green" />
          </div>

          {investments.length > 0 && (() => {
            const ongoing = investments.filter((inv: InvestmentItem) => inv.status !== 'completed' && inv.status !== 'cancelled');
            const completed = investments.filter((inv: InvestmentItem) => inv.status === 'completed' || inv.status === 'cancelled');
            return (
              <div className="space-y-6">
                {ongoing.length > 0 && (
                  <InvestmentTable
                    title="Ongoing Investments"
                    items={ongoing}
                    isDark={isDark}
                  />
                )}
                {completed.length > 0 && (
                  <InvestmentTable
                    title="Completed Investments"
                    items={completed}
                    isDark={isDark}
                  />
                )}
              </div>
            );
          })()}
        </Card>
      )}

      {/* Account Statement */}
      {accountStatement && (
        <AccountStatementCard data={accountStatement} userRole={user.role} />
      )}

      {/* Activity Log */}
      {recentActivity.length > 0 && (
        <Card>
          <CardHeader title="Letzte Aktivitäten" />
          <div className="space-y-3">
            {recentActivity.map((activity: ActivityItem, index: number) => (
              <div key={index} className={clsx('flex items-center gap-4 p-3 rounded-lg', isDark ? 'bg-slate-900/70 border border-slate-700' : 'bg-gray-50')}>
                <div className="w-2 h-2 bg-fin1-primary rounded-full" />
                <div className="flex-1">
                  <p className={clsx('text-sm font-medium', adminPrimary(isDark))}>{activity.description || activity.action}</p>
                  <p className={clsx('text-xs', adminStatTitle(isDark))}>{formatDateTime(activity.createdAt)}</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      <UserActionModal
        showActionModal={showActionModal}
        actionReason={actionReason}
        isDark={isDark}
        loading={statusMutation.isPending || resetMutation.isPending}
        onChangeReason={setActionReason}
        onClose={() => {
          setShowActionModal(null);
          setActionReason('');
        }}
        onConfirm={() => {
          if (showActionModal === 'suspend') {
            statusMutation.mutate({ status: 'suspended', reason: actionReason });
          } else if (showActionModal === 'reactivate') {
            statusMutation.mutate({ status: 'active', reason: actionReason });
          } else if (showActionModal === 'reset') {
            resetMutation.mutate(actionReason);
          }
        }}
      />
    </div>
  );
}
