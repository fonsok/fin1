import { useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card, Button, Input, Badge } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { cloudFunction } from '../../../api/admin';

import { adminMuted } from '../../../utils/adminThemeClasses';
type WalletMode = 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal';

const SCOPE_KEYS = [
  'walletActionModeGlobal',
  'walletActionModeInvestor',
  'walletActionModeTrader',
  'walletActionModeIndividual',
  'walletActionModeCompany',
] as const;

type ScopeKey = (typeof SCOPE_KEYS)[number];

const SCOPE_LABELS: Record<ScopeKey, string> = {
  walletActionModeGlobal: 'Global',
  walletActionModeInvestor: 'Rolle: Investor',
  walletActionModeTrader: 'Rolle: Trader',
  walletActionModeIndividual: 'Account: Privatperson',
  walletActionModeCompany: 'Account: Company',
};

function toMode(allowDeposit: boolean, allowWithdrawal: boolean): WalletMode {
  if (allowDeposit && allowWithdrawal) return 'deposit_and_withdrawal';
  if (allowDeposit) return 'deposit_only';
  if (allowWithdrawal) return 'withdrawal_only';
  return 'disabled';
}

export function WalletActionModeBatchCard() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();
  const [isExpanded, setIsExpanded] = useState(false);
  const [selectedScopes, setSelectedScopes] = useState<Record<ScopeKey, boolean>>({
    walletActionModeGlobal: true,
    walletActionModeInvestor: false,
    walletActionModeTrader: false,
    walletActionModeIndividual: false,
    walletActionModeCompany: false,
  });
  const [allowDeposit, setAllowDeposit] = useState(true);
  const [allowWithdrawal, setAllowWithdrawal] = useState(true);
  const [reason, setReason] = useState('');
  const [uiError, setUiError] = useState<string | null>(null);

  const selectedScopeKeys = useMemo(
    () => SCOPE_KEYS.filter((key) => selectedScopes[key]),
    [selectedScopes],
  );

  const mutation = useMutation({
    mutationFn: async () => {
      const newValue = toMode(allowDeposit, allowWithdrawal);
      for (const parameterName of selectedScopeKeys) {
        await cloudFunction('requestConfigurationChange', {
          parameterName,
          newValue,
          reason,
        });
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['configuration'] });
      queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      setReason('');
      setUiError(null);
    },
    onError: (err: unknown) => {
      const backendMessage =
        typeof err === 'object' &&
        err !== null &&
        'message' in err &&
        typeof (err as { message?: unknown }).message === 'string'
          ? (err as { message: string }).message
          : null;
      setUiError(backendMessage || 'Fehler beim Beantragen der Änderung.');
    },
  });

  const submit = () => {
    setUiError(null);
    if (selectedScopeKeys.length === 0) {
      setUiError('Bitte mindestens einen Scope auswählen.');
      return;
    }
    if (!reason.trim()) {
      setUiError('Bitte eine Begründung eingeben.');
      return;
    }
    mutation.mutate();
  };

  return (
    <Card>
      <div className="flex items-center justify-between gap-3">
        <h3 className="text-md font-semibold mb-2 flex items-center gap-2">
          Konto-Aktionsmodus
          <Badge variant="warning" size="sm">4-Augen</Badge>
        </h3>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => setIsExpanded((prev) => !prev)}
        >
          {isExpanded ? 'Auswahl verbergen' : 'Auswahl anzeigen'}
        </Button>
      </div>

      <p className={clsx('text-sm mb-4', adminMuted(isDark))}>
        Gewünschte Scopes und Transaktionsarten per Checkbox auswählen.
      </p>
      <p className={clsx('text-sm mb-4', adminMuted(isDark))}>
        Funktionsweise: Mit den Checkboxen bei Transaktionsarten steuerst du direkt, was erlaubt ist.
        <br />
        - Einzahlung aktiv: Nutzer dürfen Geld ins Konto einzahlen.
        <br />
        - Auszahlung aktiv: Nutzer dürfen Geld aus dem Konto auszahlen.
        <br />
        - Beide aktiv: Ein- und Auszahlungen erlaubt.
        <br />
        - Beide deaktiviert: Ein- und Auszahlungen gesperrt.
        <br />
        Der globale Scope gilt für alle Konten; Rollen- und Account-Scopes können danach weiter einschränken.
        Jede Änderung wird als 4-Augen-Antrag erstellt und erst nach Freigabe wirksam.
      </p>

      {isExpanded && (
        <>
          <div className="space-y-3 mb-4">
            {SCOPE_KEYS.map((key) => (
              <label key={key} className="flex items-center gap-2">
                <span className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={selectedScopes[key]}
                    onChange={(e) => setSelectedScopes((prev) => ({ ...prev, [key]: e.target.checked }))}
                  />
                  <span>{SCOPE_LABELS[key]}</span>
                </span>
              </label>
            ))}
          </div>

          <div className="mb-4">
            <p className="text-sm font-medium mb-2">Transaktionsarten</p>
            <div className="flex flex-wrap gap-4">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={allowDeposit}
                  onChange={(e) => setAllowDeposit(e.target.checked)}
                />
                Einzahlung
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={allowWithdrawal}
                  onChange={(e) => setAllowWithdrawal(e.target.checked)}
                />
                Auszahlung
              </label>
            </div>
          </div>

          <Input
            placeholder="Begründung für die Änderung..."
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="w-full mb-3"
          />

          {uiError && <p className="text-sm text-red-500 mb-2">{uiError}</p>}
          {mutation.isSuccess && <p className="text-sm text-green-600 mb-2">Änderungsanträge wurden erstellt.</p>}

          <Button size="sm" onClick={submit} loading={mutation.isPending}>
            Änderungen beantragen
          </Button>
        </>
      )}
    </Card>
  );
}
