import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { Card, Button, Input, Badge } from '../../../components/ui';
import { useTheme } from '../../../context/ThemeContext';
import { cloudFunction } from '../../../api/admin';
import { formatPercentage } from '../../../utils/format';
import { adminMuted } from '../../../utils/adminThemeClasses';
import type { PendingConfigChange } from '../types';
import {
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
  parseLocalizedNumberInput,
} from '../localizedNumberInput';

interface CommissionRateTraderAppCardProps {
  config: Record<string, number | string | boolean>;
  pendingRequests?: PendingConfigChange[];
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
}: CommissionRateTraderAppCardProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();

  const currentRates = useMemo(() => readCommissionRatesFromConfig(config), [config]);
  const [isExpanded, setIsExpanded] = useState(false);
  const [totalInput, setTotalInput] = useState('');
  const [splitPreset, setSplitPreset] = useState<CommissionSplitPresetId>('equal_50_50');
  const [customTraderInput, setCustomTraderInput] = useState('');
  const [customAppInput, setCustomAppInput] = useState('');
  const [reason, setReason] = useState('');
  const [uiError, setUiError] = useState<string | null>(null);

  const resetDraftFromConfig = () => {
    const preset = detectPresetFromRates(currentRates);
    setTotalInput(formatLocalizedInput(String(currentRates.investorCommissionRateTotal)));
    setSplitPreset(preset);
    setCustomTraderInput(formatLocalizedInput(String(currentRates.traderCommissionRate)));
    setCustomAppInput(formatLocalizedInput(String(currentRates.appCommissionRate)));
    setReason('');
    setUiError(null);
  };

  useEffect(() => {
    if (!isExpanded) {
      return;
    }
    resetDraftFromConfig();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only when opening editor
  }, [isExpanded]);

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
      setIsExpanded(false);
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
        setCustomTraderInput(formatLocalizedInput(String(rates.traderCommissionRate)));
        setCustomAppInput(formatLocalizedInput(String(rates.appCommissionRate)));
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
    setCustomTraderInput(formatLocalizedInput(String(rates.traderCommissionRate)));
    setCustomAppInput(formatLocalizedInput(String(rates.appCommissionRate)));
  };

  const pending = hasPendingCommissionChange(pendingRequests);

  return (
    <Card className="mb-4">
      <div className="flex items-center justify-between gap-3">
        <h3 className="text-md font-semibold mb-2 flex items-center gap-2">
          {COMMISSION_RATE_BUNDLE_DISPLAY_NAME}
          <Badge variant="warning" size="sm">4-Augen</Badge>
          {pending && <Badge variant="warning" size="sm">Ausstehend</Badge>}
        </h3>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => {
            if (isExpanded) {
              resetDraftFromConfig();
            }
            setIsExpanded((prev) => !prev);
          }}
        >
          {isExpanded ? 'Abbrechen' : 'Bearbeiten'}
        </Button>
      </div>

      <p className={clsx('text-sm mb-2', adminMuted(isDark))}>
        Gesamtprovision für Investoren (Collection Bill „Commission“) mit Aufteilung Trader / App.
        Summe muss exakt gelten: Trader + App = Gesamt.
      </p>
      <p className={clsx('text-sm font-medium mb-4', adminMuted(isDark))}>
        Aktuell: {formatCommissionRatesSummary(currentRates)}
      </p>

      {isExpanded && (
        <>
          <div className="grid gap-4 md:grid-cols-2 mb-4">
            <div>
              <label className="block text-sm font-medium mb-1">Gesamtprovision</label>
              <Input
                value={totalInput}
                onChange={(e) => onTotalChange(e.target.value)}
                placeholder="z. B. 0,10"
              />
              {Number.isFinite(parsedTotal) && (
                <p className={clsx('text-xs mt-1', adminMuted(isDark))}>
                  {formatPercentage(parsedTotal)} gesamt
                </p>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Aufteilung</label>
              <select
                className={clsx(
                  'w-full rounded-md border px-3 py-2 text-sm',
                  isDark ? 'bg-slate-900 border-slate-700' : 'bg-white border-slate-300',
                )}
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
            <div className="grid gap-4 md:grid-cols-2 mb-4">
              <div>
                <label className="block text-sm font-medium mb-1">Trader-Provision</label>
                <Input
                  value={customTraderInput}
                  onChange={(e) => setCustomTraderInput(formatLocalizedInput(e.target.value))}
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">App-Erfolgsprovision</label>
                <Input
                  value={customAppInput}
                  onChange={(e) => setCustomAppInput(formatLocalizedInput(e.target.value))}
                />
              </div>
            </div>
          )}

          {draftRates && (
            <p className={clsx('text-sm mb-4', adminMuted(isDark))}>
              Vorschau: {formatCommissionRatesSummary(draftRates)}
            </p>
          )}

          <Input
            placeholder="Begründung für die Änderung..."
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="w-full mb-3"
          />

          {uiError && <p className="text-sm text-red-500 mb-2">{uiError}</p>}
          {mutation.isSuccess && (
            <p className="text-sm text-green-600 mb-2">Änderungsantrag wurde erstellt.</p>
          )}

          <Button size="sm" onClick={submit} loading={mutation.isPending}>
            Änderung beantragen
          </Button>
        </>
      )}
    </Card>
  );
}
