import { useState, useMemo, useCallback } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { cloudFunction } from '../../../api/admin';
import { formatCurrency, formatPercentage } from '../../../utils/format';
import { useTheme } from '../../../context/ThemeContext';
import type { PendingConfigChange } from '../types';
import { PARAMETER_DEFINITIONS } from '../parameterDefinitions';
import { CONFIG_DEFAULT_VALUES, resolveConfig, type ConfigResponse } from '../configResolve';
import { getAppWithholdsLabel } from '../../../constants/branding';
import {
  formatLocalizedNumericValue,
  formatLocalizedInput,
  parseLocalizedNumberInput,
} from '../localizedNumberInput';

const normalizeTaxCollectionMode = (value: unknown): 'customer_self_reports' | 'platform_withholds' =>
  value === 'platform_withholds' ? 'platform_withholds' : 'customer_self_reports';

const normalizeWalletActionMode = (
  value: unknown,
): 'disabled' | 'deposit_only' | 'withdrawal_only' | 'deposit_and_withdrawal' => {
  if (value === 'deposit_only') return 'deposit_only';
  if (value === 'withdrawal_only') return 'withdrawal_only';
  if (value === 'deposit_and_withdrawal') return 'deposit_and_withdrawal';
  return 'disabled';
};

export function useConfigurationPage() {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const queryClient = useQueryClient();
  const [editingParam, setEditingParam] = useState<string | null>(null);
  const [editValue, setEditValue] = useState<string>('');
  const [changeReason, setChangeReason] = useState<string>('');
  const [showPending, setShowPending] = useState(false);
  const [crossLimitError, setCrossLimitError] = useState<string | null>(null);
  const [editError, setEditError] = useState<string | null>(null);

  const { data, isLoading, error } = useQuery({
    queryKey: ['configuration'],
    queryFn: () => cloudFunction<ConfigResponse>('getConfiguration'),
  });

  const { data: pendingData } = useQuery({
    queryKey: ['pendingConfigChanges'],
    queryFn: () =>
      cloudFunction<{ requests: PendingConfigChange[]; total: number }>('getPendingConfigurationChanges'),
  });

  const config = useMemo(() => resolveConfig(data), [data]);

  const requestChangeMutation = useMutation({
    mutationFn: (params: { parameterName: string; newValue: number | boolean | string; reason: string }) =>
      cloudFunction('requestConfigurationChange', params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['configuration'] });
      queryClient.invalidateQueries({ queryKey: ['pendingConfigChanges'] });
      setEditingParam(null);
      setEditValue('');
      setChangeReason('');
      setCrossLimitError(null);
      setEditError(null);
    },
    onError: (err: unknown) => {
      const backendMessage =
        typeof err === 'object' &&
        err !== null &&
        'message' in err &&
        typeof (err as { message?: unknown }).message === 'string'
          ? (err as { message: string }).message
          : null;
      setEditError(backendMessage || 'Fehler beim Speichern. Bitte Eingaben prüfen.');
    },
  });

  const formatValue = useCallback((key: string, value: number | string | boolean): string => {
    const def = PARAMETER_DEFINITIONS[key];
    if (!def) return String(value ?? '');

    if (def.type === 'boolean') {
      const on = value === true || value === 'true' || value === 1 || value === '1';
      return on ? 'Aktiv' : 'Deaktiviert';
    }
    if (def.type === 'string') {
      if (key === 'taxCollectionMode') {
        return normalizeTaxCollectionMode(value) === 'customer_self_reports'
          ? 'Kunde führt selbst ab'
          : getAppWithholdsLabel(config);
      }
      if (key.startsWith('walletActionMode')) {
        const mode = normalizeWalletActionMode(value);
        if (mode === 'deposit_only') return 'Nur Einzahlungen';
        if (mode === 'withdrawal_only') return 'Nur Auszahlungen';
        if (mode === 'deposit_and_withdrawal') return 'Ein- und Auszahlungen';
        return 'Deaktiviert';
      }
      return String(value ?? '');
    }

    const num = Number(value);
    switch (def.type) {
      case 'percentage':
        return formatPercentage(num);
      case 'percent_display':
        return `${Number.isFinite(num) ? num : 0} %`;
      case 'currency':
        return formatCurrency(num);
      default:
        return String(value ?? '');
    }
  }, [config]);

  const validateCrossLimits = useCallback(
    (paramKey: string, raw: string) => {
      if (
        paramKey !== 'daily_transaction_limit' &&
        paramKey !== 'weekly_transaction_limit' &&
        paramKey !== 'monthly_transaction_limit'
      ) {
        setCrossLimitError(null);
        return;
      }
      const parsed = parseLocalizedNumberInput(raw);
      if (!isFinite(parsed)) {
        setCrossLimitError(null);
        return;
      }
      const dailyCurrent = Number(config['daily_transaction_limit'] ?? CONFIG_DEFAULT_VALUES.daily_transaction_limit);
      const weeklyCurrent = Number(config['weekly_transaction_limit'] ?? CONFIG_DEFAULT_VALUES.weekly_transaction_limit);
      const monthlyCurrent = Number(
        config['monthly_transaction_limit'] ?? CONFIG_DEFAULT_VALUES.monthly_transaction_limit,
      );

      const nextDaily = paramKey === 'daily_transaction_limit' ? parsed : dailyCurrent;
      const nextWeekly = paramKey === 'weekly_transaction_limit' ? parsed : weeklyCurrent;
      const nextMonthly = paramKey === 'monthly_transaction_limit' ? parsed : monthlyCurrent;

      if (nextDaily <= nextWeekly && nextWeekly <= nextMonthly) {
        setCrossLimitError(null);
      } else {
        setCrossLimitError('Bedingung daily ≤ weekly ≤ monthly muss erfüllt sein.');
      }
    },
    [config],
  );

  const handleStartEdit = useCallback((key: string, currentValue: number | string | boolean) => {
    const def = PARAMETER_DEFINITIONS[key];
    setEditingParam(key);
    if (def?.type === 'boolean' || def?.type === 'string') {
      setEditValue(
        key === 'taxCollectionMode'
          ? normalizeTaxCollectionMode(currentValue)
          : key.startsWith('walletActionMode')
            ? normalizeWalletActionMode(currentValue)
          : String(currentValue),
      );
    } else {
      setEditValue(formatLocalizedInput(String(currentValue)));
    }
    setChangeReason('');
    setCrossLimitError(null);
    setEditError(null);
  }, []);

  const handleSaveChange = useCallback(() => {
    if (!editingParam || !changeReason.trim()) return;
    setEditError(null);

    const def = PARAMETER_DEFINITIONS[editingParam];
    if (!def) return;

    let newValue: number | boolean | string;

    if (def.type === 'boolean') {
      newValue = editValue === 'true' || editValue === '1';
    } else if (def.type === 'string') {
      newValue = editingParam === 'legalAppName' ? editValue.trim() : editValue;
      if (!newValue) {
        setEditError(
          editingParam === 'taxCollectionMode'
            ? 'Bitte einen gültigen Modus auswählen.'
            : 'Bitte einen gültigen Text eingeben.',
        );
        return;
      }
    } else {
      newValue = parseLocalizedNumberInput(editValue);
      if (isNaN(newValue)) {
        setEditError('Bitte einen gültigen Zahlenwert eingeben.');
        return;
      }
      if (def.min !== undefined && newValue < def.min) {
        setEditError(`Wert zu klein. Minimum: ${formatLocalizedNumericValue(def.min)}.`);
        return;
      }
      if (def.max !== undefined && newValue > def.max) {
        setEditError(`Wert zu groß. Maximum: ${formatLocalizedNumericValue(def.max)}.`);
        return;
      }
    }

    if (
      editingParam === 'serviceChargeLegacyClientFallbackEnabled'
      && newValue === false
    ) {
      const allowedFromRaw = String(
        config.serviceChargeLegacyDisableAllowedFrom ?? '2999-12-31',
      );
      const today = new Date();
      const isoToday = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
      if (isoToday < allowedFromRaw) {
        setEditError(`Legacy-Fallback darf erst ab ${allowedFromRaw} deaktiviert werden.`);
        return;
      }
    }

    if (editingParam === 'minInvestment' || editingParam === 'maxInvestment') {
      const minCurrent = Number(config.minInvestment ?? CONFIG_DEFAULT_VALUES.minInvestment);
      const maxCurrent = Number(config.maxInvestment ?? CONFIG_DEFAULT_VALUES.maxInvestment);
      const nextMin = editingParam === 'minInvestment' ? Number(newValue) : minCurrent;
      const nextMax = editingParam === 'maxInvestment' ? Number(newValue) : maxCurrent;
      if (nextMin > nextMax) {
        setEditError('Mindestinvestmentbetrag darf den Maximuminvestmentbetrag nicht übersteigen.');
        return;
      }
    }

    if (
      editingParam === 'daily_transaction_limit' ||
      editingParam === 'weekly_transaction_limit' ||
      editingParam === 'monthly_transaction_limit'
    ) {
      const dailyCurrent = Number(config['daily_transaction_limit'] ?? CONFIG_DEFAULT_VALUES.daily_transaction_limit);
      const weeklyCurrent = Number(config['weekly_transaction_limit'] ?? CONFIG_DEFAULT_VALUES.weekly_transaction_limit);
      const monthlyCurrent = Number(
        config['monthly_transaction_limit'] ?? CONFIG_DEFAULT_VALUES.monthly_transaction_limit,
      );

      const nextDaily = editingParam === 'daily_transaction_limit' ? Number(newValue) : dailyCurrent;
      const nextWeekly = editingParam === 'weekly_transaction_limit' ? Number(newValue) : weeklyCurrent;
      const nextMonthly = editingParam === 'monthly_transaction_limit' ? Number(newValue) : monthlyCurrent;

      if (!(nextDaily <= nextWeekly && nextWeekly <= nextMonthly)) {
        setCrossLimitError('Bedingung daily ≤ weekly ≤ monthly muss erfüllt sein.');
        setEditError('Transaktionslimits ungültig: daily ≤ weekly ≤ monthly erforderlich.');
        return;
      }
      setCrossLimitError(null);
    }

    requestChangeMutation.mutate({
      parameterName: editingParam,
      newValue,
      reason: changeReason,
    });
  }, [editingParam, changeReason, editValue, config, requestChangeMutation]);

  const handleCancelEdit = useCallback(() => {
    setEditingParam(null);
    setCrossLimitError(null);
    setEditError(null);
  }, []);

  const financialParams = useMemo(() => {
    const entries = Object.entries(PARAMETER_DEFINITIONS).filter(([, def]) => def.category === 'financial');
    const sorted = [...entries].sort(([, a], [, b]) =>
      a.displayName.localeCompare(b.displayName, 'de', { sensitivity: 'base' }),
    );
    const maxEntry = sorted.find(([k]) => k === 'maxInvestment');
    const withoutMax = sorted.filter(([k]) => k !== 'maxInvestment');
    const minIdx = withoutMax.findIndex(([k]) => k === 'minInvestment');
    if (maxEntry && minIdx !== -1) {
      withoutMax.splice(minIdx + 1, 0, maxEntry);
      return withoutMax;
    }
    return sorted;
  }, []);
  const displayParams = useMemo(
    () => Object.entries(PARAMETER_DEFINITIONS).filter(([key, def]) =>
      def.category === 'display' && !key.startsWith('walletActionMode'),
    ),
    [],
  );
  const systemParams = useMemo(
    () => Object.entries(PARAMETER_DEFINITIONS).filter(([, def]) => def.category === 'system'),
    [],
  );
  const taxParams = useMemo(
    () => {
      const entries = Object.entries(PARAMETER_DEFINITIONS).filter(([, def]) => def.category === 'tax');
      const sortOrder: Record<string, number> = {
        vatRate: 0,
        taxCollectionMode: 1,
        withholdingTaxRate: 2,
        solidaritySurchargeRate: 3,
      };
      return entries.sort(([a], [b]) => (sortOrder[a] ?? 99) - (sortOrder[b] ?? 99));
    },
    [],
  );

  const pendingCount = pendingData?.requests?.length || 0;

  const onFinancialEditValueChange = useCallback(
    (value: string, key: string) => {
      const def = PARAMETER_DEFINITIONS[key];
      const nextValue =
        def?.type === 'boolean' || def?.type === 'string'
          ? value
          : formatLocalizedInput(value);
      setEditValue(nextValue);
      setEditError(null);
      validateCrossLimits(key, nextValue);
    },
    [validateCrossLimits],
  );

  const onDisplayEditValueChange = useCallback((value: string) => {
    const def = editingParam ? PARAMETER_DEFINITIONS[editingParam] : undefined;
    setEditValue(def?.type === 'boolean' ? value : formatLocalizedInput(value));
    setEditError(null);
  }, [editingParam]);

  return {
    isDark,
    isLoading,
    error,
    queryClient,
    showPending,
    setShowPending,
    config,
    pendingData,
    pendingCount,
    financialParams,
    taxParams,
    systemParams,
    displayParams,
    editingParam,
    editValue,
    changeReason,
    setChangeReason,
    crossLimitError,
    editError,
    requestChangeMutation,
    handleStartEdit,
    handleSaveChange,
    handleCancelEdit,
    formatValue,
    onFinancialEditValueChange,
    onDisplayEditValueChange,
  };
}
