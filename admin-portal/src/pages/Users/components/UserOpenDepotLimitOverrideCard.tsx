import { useEffect, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Button, Input, Badge, AdminCollapsibleCard } from '../../../components/ui';
import { requestUserOpenDepotLimitChange } from '../../../api/admin';
import type { UserOpenDepotLimitControls } from '../../../api/admin/types';
import {
  adminMuted,
  adminPrimary,
  adminSoft,
  adminStrong,
} from '../../../utils/adminThemeClasses';

interface UserOpenDepotLimitOverrideCardProps {
  userId: string;
  openDepotLimitControls?: UserOpenDepotLimitControls;
  isDark: boolean;
}

function formatLimitValue(limit: number | null | undefined): string {
  if (limit === null || limit === undefined) {
    return 'kein Override (global)';
  }
  return `${limit} Position${limit === 1 ? '' : 'en'}`;
}

function limitsAreEqual(a: number | null | undefined, b: number | null | undefined): boolean {
  if (a === null || a === undefined || b === null || b === undefined) {
    return a === b;
  }
  return Math.floor(a) === Math.floor(b);
}

export function UserOpenDepotLimitOverrideCard({
  userId,
  openDepotLimitControls,
  isDark,
}: UserOpenDepotLimitOverrideCardProps) {
  const queryClient = useQueryClient();
  const muted = adminMuted(isDark);

  if (!openDepotLimitControls?.applicable) {
    return null;
  }

  const globalLimit = openDepotLimitControls.globalLimit;
  const storedOverride = openDepotLimitControls.storedOverride;
  const currentOverride = openDepotLimitControls.userOverride;
  const pendingOverride = openDepotLimitControls.pendingOverride;
  const effectiveLimit = openDepotLimitControls.effectiveLimit;
  const openDepotPositions = openDepotLimitControls.openDepotPositions;

  const [limitInput, setLimitInput] = useState('');
  const [effectiveFromInput, setEffectiveFromInput] = useState('');
  const [reason, setReason] = useState('');
  const [uiError, setUiError] = useState<string | null>(null);

  const seedLimit = storedOverride ?? currentOverride ?? globalLimit ?? 5;

  const resetDraft = () => {
    setLimitInput(String(seedLimit));
    setEffectiveFromInput('');
    setReason('');
    setUiError(null);
  };

  useEffect(() => {
    resetDraft();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- re-seed when controls change
  }, [openDepotLimitControls]);

  const parsedLimit = Math.floor(Number(limitInput.replace(',', '.')));

  const mutation = useMutation({
    mutationFn: async (payload: { limit?: number; clearOverride?: boolean }) => {
      if (payload.clearOverride) {
        return requestUserOpenDepotLimitChange(userId, {
          clearOverride: true,
          reason,
        });
      }
      if (payload.limit === undefined) {
        throw new Error('Limit fehlt');
      }
      return requestUserOpenDepotLimitChange(userId, {
        maxOpenDepotPositions: payload.limit,
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

  const collapsedSummary = `${formatLimitValue(effectiveLimit)} · offen: ${openDepotPositions}`;

  const submitOverride = () => {
    setUiError(null);
    if (!reason.trim()) {
      setUiError('Bitte eine Begründung eingeben.');
      return;
    }
    if (!Number.isFinite(parsedLimit) || parsedLimit < 1 || parsedLimit > 50) {
      setUiError('Limit muss eine ganze Zahl zwischen 1 und 50 sein.');
      return;
    }
    if (storedOverride !== null && limitsAreEqual(parsedLimit, storedOverride)) {
      setUiError('Keine Änderung gegenüber dem gespeicherten Override.');
      return;
    }
    mutation.mutate({ limit: parsedLimit });
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
      title="Individuelles Depot-Positions-Limit (Trader)"
      isDark={isDark}
      panelId="user-open-depot-limit-override-panel"
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
        Begrenzt gleichzeitig offene Depot-Positionen (Restmenge &gt; 0) für neue Käufe.
        Priorität: Trader-Override → global (Konfiguration → Finanzparameter).
        Server blockiert weitere Käufe via <span className="font-mono">executePairedBuy</span>.
      </p>

      <div className="grid gap-3 md:grid-cols-2 text-sm">
        <div>
          <span className={muted}>Global: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {formatLimitValue(globalLimit)}
          </span>
        </div>
        <div>
          <span className={muted}>Aktuell offen: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {openDepotPositions}
          </span>
        </div>
        <div>
          <span className={muted}>Gespeicherter Override: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {formatLimitValue(storedOverride)}
          </span>
          {pendingOverride !== null && (
            <span className={clsx('ml-2 text-xs', adminSoft(isDark))}>(geplant)</span>
          )}
        </div>
        <div>
          <span className={muted}>Aktiver Override: </span>
          <span className={clsx('font-medium', adminPrimary(isDark))}>
            {formatLimitValue(currentOverride)}
          </span>
        </div>
        <div className="md:col-span-2">
          <span className={muted}>Effektives Limit: </span>
          <span className={clsx('font-semibold', adminStrong(isDark))}>
            {formatLimitValue(effectiveLimit)}
          </span>
          {openDepotLimitControls.source && (
            <span className={clsx('ml-2 text-xs', adminSoft(isDark))}>
              (Quelle: {openDepotLimitControls.source})
            </span>
          )}
        </div>
        {openDepotLimitControls.effectiveFrom && (
          <div className="md:col-span-2 text-xs">
            <span className={muted}>Override wirksam ab: </span>
            <span>{openDepotLimitControls.effectiveFrom}</span>
          </div>
        )}
      </div>

      <div className="max-w-xs">
        <label className={clsx('block text-sm font-medium mb-1', muted)}>
          Max. offene Positionen
        </label>
        <Input
          value={limitInput}
          onChange={(e) => setLimitInput(e.target.value.replace(/[^\d]/g, ''))}
          inputMode="numeric"
          className="w-32"
        />
        <p className={clsx('text-xs mt-1', muted)}>1–50 (ganze Zahl)</p>
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
