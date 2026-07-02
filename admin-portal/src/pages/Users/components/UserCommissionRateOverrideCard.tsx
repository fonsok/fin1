import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Button, Input, Badge, AdminCollapsibleCard } from '../../../components/ui';
import { formatPercentage } from '../../../utils/format';
import { requestUserCommissionRateBundleChange } from '../../../api/admin';
import type { UserCommissionControls } from '../../../api/admin/types';
import {
  adminControlField,
  adminMuted,
  adminPrimary,
  adminSoft,
  adminStrong,
} from '../../../utils/adminThemeClasses';
import {
  COMMISSION_SPLIT_PRESETS,
  computeRatesFromPreset,
  detectPresetFromRates,
  formatCommissionRatesSummary,
  formatSplitPresetLabel,
  ratesAreEqual,
  roundRate,
  validateCommissionRates,
  type CommissionRates,
  type CommissionSplitPresetId,
} from '../../Configuration/commissionRateTraderApp';
import {
  formatLocalizedInput,
  formatRateInputFromNumber,
  parseLocalizedNumberInput,
} from '../../Configuration/localizedNumberInput';

interface UserCommissionRateOverrideCardProps {
  userId: string;
  userRole: string;
  commissionControls?: UserCommissionControls;
  isDark: boolean;
}

function readRatesFromControls(controls?: UserCommissionControls): CommissionRates | null {
  const source = controls?.storedOverride ?? controls?.userOverride ?? controls?.globalRates;
  if (!source) {
    return null;
  }
  return {
    investorCommissionRateTotal: roundRate(source.investorCommissionRateTotal),
    traderCommissionRate: roundRate(source.traderCommissionRate),
    appCommissionRate: roundRate(source.appCommissionRate),
  };
}

function formatBundleValue(bundle: {
  investorCommissionRateTotal: number;
  traderCommissionRate: number;
  appCommissionRate: number;
} | null | undefined): string {
  if (!bundle) {
    return 'kein Override (global)';
  }
  return formatCommissionRatesSummary({
    investorCommissionRateTotal: bundle.investorCommissionRateTotal,
    traderCommissionRate: bundle.traderCommissionRate,
    appCommissionRate: bundle.appCommissionRate,
  });
}

export function UserCommissionRateOverrideCard({
  userId,
  userRole,
  commissionControls,
  isDark,
}: UserCommissionRateOverrideCardProps) {
  const queryClient = useQueryClient();
  const muted = adminMuted(isDark);
  const applicableRole = commissionControls?.applicableOverrideRole;
  const globalRates = commissionControls?.globalRates;
  const storedOverride = commissionControls?.storedOverride;
  const currentOverride = commissionControls?.userOverride;
  const pendingOverride = commissionControls?.pendingOverride;
  const effectiveRates = commissionControls?.effectiveRates;

  const [totalInput, setTotalInput] = useState('');
  const [splitPreset, setSplitPreset] = useState<CommissionSplitPresetId>('equal_50_50');
  const [customTraderInput, setCustomTraderInput] = useState('');
  const [customAppInput, setCustomAppInput] = useState('');
  const [effectiveFromInput, setEffectiveFromInput] = useState('');
  const [reason, setReason] = useState('');
  const [uiError, setUiError] = useState<string | null>(null);

  const draftSeedRates = useMemo(() => {
    return readRatesFromControls(commissionControls) ?? {
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.05,
      appCommissionRate: 0.05,
    };
  }, [commissionControls]);

  const resetDraft = () => {
    const preset = detectPresetFromRates(draftSeedRates);
    setTotalInput(formatRateInputFromNumber(draftSeedRates.investorCommissionRateTotal));
    setSplitPreset(preset);
    setCustomTraderInput(formatRateInputFromNumber(draftSeedRates.traderCommissionRate));
    setCustomAppInput(formatRateInputFromNumber(draftSeedRates.appCommissionRate));
    setEffectiveFromInput('');
    setReason('');
    setUiError(null);
  };

  useEffect(() => {
    resetDraft();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- re-seed when controls change
  }, [commissionControls]);

  const parsedTotal = parseLocalizedNumberInput(totalInput);
  const draftRates = useMemo((): CommissionRates | null => {
    if (!Number.isFinite(parsedTotal) || parsedTotal < 0 || parsedTotal > 1) {
      return null;
    }
    if (splitPreset === 'custom') {
      const trader = parseLocalizedNumberInput(customTraderInput);
      const app = parseLocalizedNumberInput(customAppInput);
      if (!Number.isFinite(trader) || !Number.isFinite(app)) {
        return null;
      }
      return {
        investorCommissionRateTotal: roundRate(parsedTotal),
        traderCommissionRate: roundRate(trader),
        appCommissionRate: roundRate(app),
      };
    }
    const preset = COMMISSION_SPLIT_PRESETS.find((entry) => entry.id === splitPreset);
    if (!preset) {
      return null;
    }
    return computeRatesFromPreset(parsedTotal, preset.traderShareOfTotal);
  }, [parsedTotal, splitPreset, customTraderInput, customAppInput]);

  const mutation = useMutation({
    mutationFn: async (payload: {
      rates?: CommissionRates;
      clearOverride?: boolean;
    }) => {
      if (payload.clearOverride) {
        return requestUserCommissionRateBundleChange(userId, {
          clearOverride: true,
          reason,
        });
      }
      if (!payload.rates) {
        throw new Error('Provisionswerte fehlen');
      }
      return requestUserCommissionRateBundleChange(userId, {
        ...payload.rates,
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

  if (!applicableRole) {
    return null;
  }

  const roleLabel = applicableRole === 'trader' ? 'Trader' : 'Investor';
  const sectionTitle = `Individuelle Erfolgsprovision (${roleLabel})`;
  const collapsedSummary = formatBundleValue(effectiveRates ?? globalRates ?? null);
  const selectControlClass = clsx(
    'w-full max-w-md rounded-md border px-3 py-2 text-sm',
    adminControlField(isDark),
  );

  const submitOverride = () => {
    setUiError(null);
    if (!reason.trim()) {
      setUiError('Bitte eine Begründung eingeben.');
      return;
    }
    if (!draftRates) {
      setUiError('Bitte gültige Provisionswerte eingeben.');
      return;
    }
    const validationError = validateCommissionRates(draftRates);
    if (validationError) {
      setUiError(validationError);
      return;
    }
    if (storedOverride && ratesAreEqual(draftRates, storedOverride)) {
      setUiError('Keine Änderung gegenüber dem gespeicherten Override.');
      return;
    }
    mutation.mutate({ rates: draftRates });
  };

  const submitClear = () => {
    setUiError(null);
    if (!reason.trim()) {
      setUiError('Bitte eine Begründung eingeben.');
      return;
    }
    if (!storedOverride) {
      setUiError('Es ist kein Override gesetzt.');
      return;
    }
    mutation.mutate({ clearOverride: true });
  };

  const onSplitChange = (nextPreset: CommissionSplitPresetId) => {
    setSplitPreset(nextPreset);
    if (nextPreset !== 'custom' && Number.isFinite(parsedTotal)) {
      const preset = COMMISSION_SPLIT_PRESETS.find((entry) => entry.id === nextPreset);
      if (preset) {
        const rates = computeRatesFromPreset(parsedTotal, preset.traderShareOfTotal);
        setCustomTraderInput(formatRateInputFromNumber(rates.traderCommissionRate));
        setCustomAppInput(formatRateInputFromNumber(rates.appCommissionRate));
      }
    }
  };

  const onTotalChange = (value: string) => {
    const formatted = formatLocalizedInput(value);
    setTotalInput(formatted);
    const total = parseLocalizedNumberInput(formatted);
    if (!Number.isFinite(total) || splitPreset === 'custom') {
      return;
    }
    const preset = COMMISSION_SPLIT_PRESETS.find((entry) => entry.id === splitPreset);
    if (!preset) {
      return;
    }
    const rates = computeRatesFromPreset(total, preset.traderShareOfTotal);
    setCustomTraderInput(formatRateInputFromNumber(rates.traderCommissionRate));
    setCustomAppInput(formatRateInputFromNumber(rates.appCommissionRate));
  };

  return (
    <AdminCollapsibleCard
      title={sectionTitle}
      isDark={isDark}
      panelId="user-commission-override-panel"
      badges={<Badge variant="warning" size="sm">4-Augen</Badge>}
      collapsedSummary={(
        <span className={muted}>
          Effektiv: {collapsedSummary}
          {currentOverride && (
            <span className={clsx('ml-2', adminSoft(isDark))}>
              · Override aktiv
            </span>
          )}
          {!currentOverride && pendingOverride && (
            <span className={clsx('ml-2', adminSoft(isDark))}>
              · Override geplant
            </span>
          )}
        </span>
      )}
    >
        <p className={clsx('text-sm', muted)}>
          Gilt für neue Investments ab Freigabe (Snapshot bei Reservierung). Bereits reservierte Investments
          behalten ihren eingefrorenen Satz. Priorität: Investment-Snapshot → {roleLabel}-Override → global.
        </p>

        <div className="grid gap-3 md:grid-cols-2 text-sm">
          <div>
            <span className={muted}>Global: </span>
            <span className={clsx('font-medium', adminPrimary(isDark))}>
              {formatBundleValue(globalRates ?? null)}
            </span>
          </div>
          <div>
            <span className={muted}>Gespeicherter Override: </span>
            <span className={clsx('font-medium', adminPrimary(isDark))}>
              {formatBundleValue(storedOverride)}
            </span>
            {pendingOverride && (
              <span className={clsx('ml-2 text-xs', adminSoft(isDark))}>(geplant)</span>
            )}
          </div>
          <div>
            <span className={muted}>Aktiver Override: </span>
            <span className={clsx('font-medium', adminPrimary(isDark))}>
              {formatBundleValue(currentOverride)}
            </span>
          </div>
          <div className="md:col-span-2">
            <span className={muted}>Effektiv für neue Buchungen ({userRole}): </span>
            <span className={clsx('font-semibold', adminStrong(isDark))}>
              {formatBundleValue(effectiveRates ?? globalRates ?? null)}
            </span>
            {effectiveRates?.source && (
              <span className={clsx('ml-2 text-xs', adminSoft(isDark))}>
                (Quelle: {effectiveRates.source})
              </span>
            )}
          </div>
          {commissionControls?.effectiveFrom && (
            <div className="md:col-span-2 text-xs">
              <span className={muted}>Override wirksam ab: </span>
              <span>{commissionControls.effectiveFrom}</span>
            </div>
          )}
        </div>

        <div className="grid gap-4 md:grid-cols-2 max-w-2xl">
          <div>
            <label className={clsx('block text-sm font-medium mb-1', muted)}>Gesamtprovision</label>
            <Input
              value={totalInput}
              onChange={(e) => onTotalChange(e.target.value)}
              placeholder="0,1"
              className="w-32"
            />
            {Number.isFinite(parsedTotal) && (
              <p className={clsx('text-xs mt-1', muted)}>{formatPercentage(parsedTotal)} gesamt</p>
            )}
          </div>
          <div>
            <label className={clsx('block text-sm font-medium mb-1', muted)}>Aufteilung</label>
            <select
              className={selectControlClass}
              value={splitPreset}
              onChange={(e) => onSplitChange(e.target.value as CommissionSplitPresetId)}
            >
              {COMMISSION_SPLIT_PRESETS.map((preset) => (
                <option key={preset.id} value={preset.id}>
                  {formatSplitPresetLabel(
                    preset,
                    Number.isFinite(parsedTotal) ? parsedTotal : draftSeedRates.investorCommissionRateTotal,
                  )}
                </option>
              ))}
            </select>
          </div>
        </div>

        {splitPreset === 'custom' && (
          <div className="grid gap-4 md:grid-cols-2 max-w-2xl">
            <div>
              <label className={clsx('block text-sm font-medium mb-1', muted)}>Trader-Provision</label>
              <Input
                value={customTraderInput}
                onChange={(e) => setCustomTraderInput(formatLocalizedInput(e.target.value))}
                className="w-32"
              />
            </div>
            <div>
              <label className={clsx('block text-sm font-medium mb-1', muted)}>App-Erfolgsprovision</label>
              <Input
                value={customAppInput}
                onChange={(e) => setCustomAppInput(formatLocalizedInput(e.target.value))}
                className="w-32"
              />
            </div>
          </div>
        )}

        {draftRates && (
          <p className={clsx('text-sm', muted)}>Vorschau: {formatCommissionRatesSummary(draftRates)}</p>
        )}

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
          {storedOverride && (
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
