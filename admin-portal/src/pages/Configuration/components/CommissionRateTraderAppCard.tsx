import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Button, Input, Badge } from '../../../components/ui';
import { cloudFunction } from '../../../api/admin';
import { formatPercentage } from '../../../utils/format';
import { listRowStripeClasses } from '../../../utils/tableStriping';
import { adminControlField, adminMuted } from '../../../utils/adminThemeClasses';
import type { PendingConfigChange } from '../types';
import {
  COMMISSION_RATE_BUNDLE_DESCRIPTION,
  COMMISSION_RATE_BUNDLE_DISPLAY_NAME,
  COMMISSION_RATE_BUNDLE_PARAMETER_NAME,
  COMMISSION_RATE_PARAMETER_KEYS,
  COMMISSION_SPLIT_PRESETS,
  computeRatesFromPreset,
  detectPresetFromRates,
  formatCommissionRatesSummary,
  formatSplitPresetLabel,
  readCommissionRatesFromConfig,
  ratesAreEqual,
  roundRate,
  type CommissionRates,
  type CommissionSplitPresetId,
  validateCommissionRates,
} from '../commissionRateTraderApp';
import {
  formatLocalizedInput,
  formatRateInputFromNumber,
  parseLocalizedNumberInput,
} from '../localizedNumberInput';

interface CommissionRateTraderAppCardProps {
  config: Record<string, number | string | boolean>;
  pendingRequests?: PendingConfigChange[];
  isDark: boolean;
  rowIndex?: number;
}

function hasPendingCommissionChange(pendingRequests?: PendingConfigChange[]): boolean {
  if (!pendingRequests?.length) {
    return false;
  }
  return pendingRequests.some(
    (request) =>
      request.parameterName === COMMISSION_RATE_BUNDLE_PARAMETER_NAME
      || COMMISSION_RATE_PARAMETER_KEYS.includes(
        request.parameterName as (typeof COMMISSION_RATE_PARAMETER_KEYS)[number],
      ),
  );
}

export function CommissionRateTraderAppCard({
  config,
  pendingRequests,
  isDark,
  rowIndex = 0,
}: CommissionRateTraderAppCardProps) {
  const queryClient = useQueryClient();
  const muted = adminMuted(isDark);
  const selectControlClass = clsx(
    'w-full max-w-md rounded-md border px-3 py-2 text-sm',
    adminControlField(isDark),
  );

  const currentRates = useMemo(() => readCommissionRatesFromConfig(config), [config]);
  const [isEditing, setIsEditing] = useState(false);
  const [totalInput, setTotalInput] = useState('');
  const [splitPreset, setSplitPreset] = useState<CommissionSplitPresetId>('equal_50_50');
  const [customTraderInput, setCustomTraderInput] = useState('');
  const [customAppInput, setCustomAppInput] = useState('');
  const [reason, setReason] = useState('');
  const [uiError, setUiError] = useState<string | null>(null);

  const resetDraftFromConfig = () => {
    const preset = detectPresetFromRates(currentRates);
    setTotalInput(formatRateInputFromNumber(currentRates.investorCommissionRateTotal));
    setSplitPreset(preset);
    setCustomTraderInput(formatRateInputFromNumber(currentRates.traderCommissionRate));
    setCustomAppInput(formatRateInputFromNumber(currentRates.appCommissionRate));
    setReason('');
    setUiError(null);
  };

  useEffect(() => {
    if (!isEditing) {
      return;
    }
    resetDraftFromConfig();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only when opening editor
  }, [isEditing]);

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
    mutationFn: async (rates: CommissionRates) => {
      await cloudFunction('requestCommissionRateBundleChange', {
        ...rates,
        reason,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['configuration'] });
      queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      setIsEditing(false);
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
      setUiError(backendMessage || 'Fehler beim Beantragen der Änderung.');
    },
  });

  const cancelEdit = () => {
    resetDraftFromConfig();
    setIsEditing(false);
  };

  const submit = () => {
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
    if (ratesAreEqual(draftRates, currentRates)) {
      setUiError('Keine Änderung gegenüber dem aktuellen Stand.');
      return;
    }
    mutation.mutate(draftRates);
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

  const pending = hasPendingCommissionChange(pendingRequests);

  return (
    <div
      className={clsx(
        'py-4 first:pt-0 last:pb-0 rounded-lg px-3 -mx-3',
        listRowStripeClasses(isDark, rowIndex, { className: 'transition-colors' }),
      )}
    >
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <span className="font-medium">{COMMISSION_RATE_BUNDLE_DISPLAY_NAME}</span>
            <Badge variant="warning" size="sm">4-Augen</Badge>
            {pending && (
              <Badge variant="info" size="sm">Änderung ausstehend</Badge>
            )}
          </div>
          <p className={clsx('text-sm mt-1', muted)}>{COMMISSION_RATE_BUNDLE_DESCRIPTION}</p>

          {isEditing ? (
            <div className="mt-3 space-y-3">
              <div className="flex items-center gap-2">
                <span className={clsx('text-sm', muted)}>Aktuell:</span>
                <span className="font-medium">{formatCommissionRatesSummary(currentRates)}</span>
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
                    <p className={clsx('text-xs mt-1', muted)}>
                      {formatPercentage(parsedTotal)} gesamt
                    </p>
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
                          Number.isFinite(parsedTotal) ? parsedTotal : currentRates.investorCommissionRateTotal,
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
                <p className={clsx('text-sm', muted)}>
                  Vorschau: {formatCommissionRatesSummary(draftRates)}
                </p>
              )}

              {uiError && <p className="text-sm text-red-500">{uiError}</p>}

              <div>
                <Input
                  placeholder="Begründung für die Änderung..."
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  className="w-full"
                />
              </div>

              <div className="flex gap-2">
                <Button
                  size="sm"
                  onClick={submit}
                  loading={mutation.isPending}
                  disabled={!reason.trim()}
                >
                  Änderung beantragen
                </Button>
                <Button variant="secondary" size="sm" onClick={cancelEdit}>
                  Abbrechen
                </Button>
              </div>

              {mutation.isSuccess && (
                <p className="text-sm text-green-600">Änderungsantrag wurde erstellt</p>
              )}
            </div>
          ) : (
            <div className="mt-2 flex flex-col gap-1">
              <span className="text-lg font-semibold text-fin1-primary">
                {formatPercentage(currentRates.investorCommissionRateTotal)}
              </span>
              <span className={clsx('text-sm', muted)}>
                Trader {formatPercentage(currentRates.traderCommissionRate)}
                {' · '}
                App {formatPercentage(currentRates.appCommissionRate)}
              </span>
            </div>
          )}
        </div>

        {!isEditing && (
          <Button
            variant="secondary"
            size="sm"
            className="self-center"
            onClick={() => setIsEditing(true)}
            disabled={pending}
          >
            Bearbeiten
          </Button>
        )}
      </div>
    </div>
  );
}
