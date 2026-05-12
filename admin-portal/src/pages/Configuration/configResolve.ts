import type { PendingConfigChange } from './types';
import { APP_NAME } from '../../constants/branding';

export interface ConfigResponse {
  config?: Record<string, number | string | boolean>;
  financial?: Record<string, number>;
  tax?: Record<string, number | string | boolean>;
  limits?: Record<string, number>;
  legal?: Record<string, number | string | boolean>;
  display?: Record<string, number | string | boolean>;
  pendingChanges?: PendingConfigChange[];
}

/** Client-side defaults matching backend `utils/configHelper` DEFAULT_CONFIG */
export const CONFIG_DEFAULT_VALUES: Record<string, number> = {
  traderCommissionRate: 0.1,
  initialAccountBalance: 0.0,
  appServiceChargeRate: 0.02,
  appServiceChargeRateCompanies: 0.02,
  withholdingTaxRate: 0.25,
  solidaritySurchargeRate: 0.055,
  vatRate: 0.19,
  minimumCashReserve: 20.0,
  minInvestment: 20.0,
  maxInvestment: 100000.0,
  daily_transaction_limit: 10000.0,
  weekly_transaction_limit: 50000.0,
  monthly_transaction_limit: 200000.0,
  poolBalanceDistributionThreshold: 5.0,
  maximumRiskExposurePercent: 2.0,
  walletFeatureEnabled: 0,
  serviceChargeInvoiceFromBackend: 0,
  serviceChargeLegacyClientFallbackEnabled: 1,
  /** 1 = true; matches backend default for account-statement voucher links */
  showDocumentReferenceLinksInAccountStatement: 1,
};

const CONFIG_DEFAULT_STRING_VALUES: Record<string, string> = {
  taxCollectionMode: 'customer_self_reports',
  walletActionModeGlobal: 'disabled',
  walletActionModeInvestor: 'deposit_and_withdrawal',
  walletActionModeTrader: 'deposit_and_withdrawal',
  walletActionModeIndividual: 'deposit_and_withdrawal',
  walletActionModeCompany: 'deposit_and_withdrawal',
  walletActionMode: 'disabled',
  legalAppName: APP_NAME,
  serviceChargeLegacyDisableAllowedFrom: '2026-05-15',
};

const TAX_COLLECTION_MODES = new Set(['customer_self_reports', 'platform_withholds']);

/**
 * Flat config map from backend response (flat `config` or legacy financial+limits + display).
 */
export function resolveConfig(data: ConfigResponse | undefined): Record<string, number | string | boolean> {
  if (!data) {
    return {
      ...CONFIG_DEFAULT_VALUES,
      ...CONFIG_DEFAULT_STRING_VALUES,
    };
  }

  const base =
    data.config && Object.keys(data.config).length > 0
      ? data.config
      : { ...data.financial, ...data.tax, ...data.limits, ...data.legal };
  const display = data.display || {};
  const raw: Record<string, number | string | boolean> = { ...base, ...display };

  const merged: Record<string, number | string | boolean> = {
    ...CONFIG_DEFAULT_VALUES,
    ...CONFIG_DEFAULT_STRING_VALUES,
  };
  for (const [k, v] of Object.entries(raw)) {
    if (v !== undefined && v !== null) merged[k] = v;
  }
  if (merged.appServiceChargeRate === undefined && raw.platformServiceChargeRate !== undefined) {
    merged.appServiceChargeRate = raw.platformServiceChargeRate;
  }
  if (typeof raw.appName === 'string' && raw.appName.trim().length > 0) {
    merged.legalAppName = raw.appName;
    merged.appName = raw.appName;
  }
  if (
    typeof merged.taxCollectionMode !== 'string' ||
    !TAX_COLLECTION_MODES.has(merged.taxCollectionMode)
  ) {
    merged.taxCollectionMode = CONFIG_DEFAULT_STRING_VALUES.taxCollectionMode;
  }
  return merged;
}
