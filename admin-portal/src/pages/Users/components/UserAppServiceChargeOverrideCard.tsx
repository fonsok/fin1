import { useEffect, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Button, Input, Badge, AdminCollapsibleCard } from '../../../components/ui';
import { formatPercentage } from '../../../utils/format';
import { requestUserAppServiceChargeChange } from '../../../api/admin';
import type { UserAppServiceChargeControls } from '../../../api/admin/types';
import {
  adminMuted,
  adminPrimary,
  adminSoft,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import {
  formatLocalizedInput,
  formatRateInputFromNumber,
  parseLocalizedNumberInput,
} from '../../Configuration/localizedNumberInput';

interface UserAppServiceChargeOverrideCardProps {
  userId: string;
  appServiceChargeControls?: UserAppServiceChargeControls;
  isDark: boolean;
}

function formatRateValue(rate: number | null | undefined): string {
  if (rate === null || rate === undefined) {
    return 'kein Override (global)';
  }
  return formatPercentage(rate);
}

function ratesAreEqual(a: number | null | undefined, b: number | null | undefined): boolean {
  if (a === null || a === undefined || b === null || b === undefined) {
    return a === b;
  }
  return Math.round(a * 10000) === Math.round(b * 10000);
}

export function UserAppServiceChargeOverrideCard({
  userId,
  appServiceChargeControls,
  isDark,
}: UserAppServiceChargeOverrideCardProps) {
  const queryClient = useQueryClient();
  const muted = adminMuted(isDark);
  const globalRate = appServiceChargeControls?.globalRate;
  const storedOverride = appServiceChargeControls?.storedOverride;
  const currentOverride = appServiceChargeControls?.userOverride;
  const pendingOverride = appServiceChargeControls?.pendingOverride;
  const effectiveRate = appServiceChargeControls?.effectiveRate;
  const accountType = appServiceChargeControls?.accountType ?? 'individual';

  const [rateInput, setRateInput] = useState('');
  const [effectiveFromInput, setEffectiveFromInput] = useState('');
  const [reason, setReason] = useState('');
  const [uiError, setUiError] = useState<string | null>(null);

  const seedRate = storedOverride ?? currentOverride ?? globalRate ?? 0.02;

  const resetDraft = () => {
    setRateInput(formatRateInputFromNumber(seedRate));
    setEffectiveFromInput('');
    setReason('');
    setUiError(null);
  };

  useEffect(() => {
    resetDraft();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- re-seed when controls change
  }, [appServiceChargeControls]);

  const parsedRate = parseLocalizedNumberInput(rateInput);

  const mutation = useMutation({
    mutationFn: async (payload: { rate?: number; clearOverride?: boolean }) => {
      if (payload.clearOverride) {
        return requestUserAppServiceChargeChange(userId, {
          clearOverride: true,
          reason,
        });
      }
      if (payload.rate === undefined) {
        throw new Error('Service-Charge-Wert fehlt');
      }
      return requestUserAppServiceChargeChange(userId, {
        appServiceChargeRate: payload.rate,
        effectiveFrom: effectiveFromInput.trim() || undefined,
        reason,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', userId] });
      queryClient.invalidateQueries({ queryKey: ['pendingApprovals'] });
      setReason('');
      setUiError(null);
    },
    onError: (err: unknown) => {
      const backendMessage =
        typeof err === 'object'
        && err !== null
        && 'message' in err
        && typeof (err as { message?: unknown }).message === 'string'
          ? (err as { message: string }).message
          : null;
      setUiError(backendMessage || 'Antrag konnte nicht erstellt werden.');
    },
  });

  if (!appServiceChargeControls?.applicable) {
    return null;
  }

  const collapsedSummary = formatRateValue(effectiveRate ?? globalRate ?? null);

  const submitOverride = () => {
    setUiError(null);
    if (!reason.trim()) {
      setUiError('Bitte eine Begründung eingeben.');
      return;
    }
    if (!Number.isFinite(parsedRate) || parsedRate < 0 || parsedRate > 0.1) {
      setUiError('App Service Charge muss zwischen 0 % und 10 % liegen.');
      return;
    }
    if (storedOverride !== null && ratesAreEqual(parsedRate, storedOverride)) {
      setUiError('Keine Änderung gegenüber dem gespeicherten Override.');
      return;
    }
    mutation.mutate({ rate: parsedRate });
  };

  const submitClear = () => {
    setUiError(null);
    if (!reason.trim()) {
      setUiError('Bitte eine Begründung eingeben.');
      return;
    }
    if (storedOverride === null) {
      setUiError('Es ist kein Override gesetzt.');
      return;
    }
    mutation.mutate({ clearOverride: true });
  };

  return (
    <AdminCollapsibleCard
      title="Individuelle App Service Charge (Investor)"
      isDark={isDark}
      panelId="user-app-service-charge-override-panel"
      badges={<Badge variant="warning" size="sm">4-Augen</Badge>}
      collapsedSummary={(
        <span className={muted}>
          Effektiv: {collapsedSummary}
          {currentOverride !== null && (
            <span className={clsx('ml-2', adminSoft(isDark))}>
              · Override aktiv
            </span>
          )}
          {currentOverride === null && pendingOverride !== null && (
            <span className={clsx('ml-2', adminSoft(isDark))}>
              · Override geplant
            </span>
          )}
        </span>
      )}
    >
      <p className={clsx('text-sm', muted)}>
        Gilt für neue Investments ab Freigabe (Snapshot bei Reservierung). Bereits reservierte Investments
        behalten ihren eingefrorenen Satz. Priorität: Investment-Snapshot → Investor-Override → global
        ({accountType === 'company' ? 'Unternehmen' : 'Privat'}).
      </p>

      <div className="grid gap-3 md:grid-cols-2 text-sm">
        <div>
          <span className={muted}>Global: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {formatRateValue(globalRate ?? null)}
          </span>
        </div>
        <div>
          <span className={muted}>Gespeicherter Override: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {formatRateValue(storedOverride)}
          </span>
          {pendingOverride !== null && (
            <span className={clsx('ml-2 text-xs', adminSoft(isDark))}>(geplant)</span>
          )}
        </div>
        <div>
          <span className={muted}>Aktiver Override: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {formatRateValue(currentOverride)}
          </span>
        </div>
        <div className="md:col-span-2">
          <span className={muted}>Effektiv für neue Buchungen: </span>
          <span className={clsx('font-semibold', adminStrong(isDark))}>
            {formatRateValue(effectiveRate ?? globalRate ?? null)}
          </span>
          {appServiceChargeControls?.source && (
            <span className={clsx('ml-2 text-xs', adminSoft(isDark))}>
              (Quelle: {appServiceChargeControls.source})
            </span>
          )}
        </div>
        {appServiceChargeControls?.effectiveFrom && (
          <div className="md:col-span-2 text-xs">
            <span className={muted}>Override wirksam ab: </span>
            <span>{appServiceChargeControls.effectiveFrom}</span>
          </div>
        )}
      </div>

      <div className="max-w-xs">
        <label className={clsx('block text-sm font-medium mb-1', muted)}>App Service Charge</label>
        <Input
          value={rateInput}
          onChange={(e) => setRateInput(formatLocalizedInput(e.target.value))}
          placeholder="0,02"
          className="w-32"
        />
        {Number.isFinite(parsedRate) && (
          <p className={clsx('text-xs mt-1', muted)}>{formatPercentage(parsedRate)}</p>
        )}
      </div>

      <div className="max-w-md">
        <label className={clsx('block text-sm font-medium mb-1', muted)}>
          Wirksam ab (optional, leer = bei Freigabe)
        </label>
        <Input
          type="datetime-local"
          value={effectiveFromInput}
          onChange={(e) => setEffectiveFromInput(e.target.value)}
        />
      </div>

      <Input
        placeholder="Begründung für die Änderung (Pflicht)"
        value={reason}
        onChange={(e) => setReason(e.target.value)}
      />

      {uiError && <p className="text-sm text-red-500">{uiError}</p>}

      <div className="flex flex-wrap gap-2">
        <Button
          size="sm"
          onClick={submitOverride}
          loading={mutation.isPending}
          disabled={!reason.trim()}
        >
          Override via 4-Augen beantragen
        </Button>
        {storedOverride !== null && (
          <Button
            variant="secondary"
            size="sm"
            onClick={submitClear}
            loading={mutation.isPending}
            disabled={!reason.trim()}
          >
            Override entfernen (4-Augen)
          </Button>
        )}
        <Button variant="secondary" size="sm" onClick={resetDraft}>
          Zurücksetzen
        </Button>
      </div>

      {mutation.isSuccess && (
        <p className={clsx('text-sm', isDark ? 'text-emerald-400' : 'text-green-600')}>
          Antrag erstellt — Freigabe unter Freigaben.
        </p>
      )}
    </AdminCollapsibleCard>
  );
}
