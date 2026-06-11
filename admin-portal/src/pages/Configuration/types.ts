// Configuration types

export interface ConfigurationParameter {
  key: string;
  value: number | string | boolean;
  displayName: string;
  description: string;
  type: 'number' | 'percentage' | 'percent_display' | 'currency' | 'boolean' | 'string';
  category: 'financial' | 'tax' | 'display' | 'system' | 'feature';
  isCritical: boolean;
  /** Omit from Finanzparameter list — edited via a dedicated composite card. */
  hiddenInParameterList?: boolean;
  min?: number;
  max?: number;
  unit?: string;
}

export interface ConfigurationData {
  parameters: ConfigurationParameter[];
  lastUpdated?: string;
  lastUpdatedBy?: string;
}

export interface PendingConfigChange {
  id: string;
  parameterName: string;
  oldValue: number | string | boolean | CommissionRateBundleValue;
  newValue: number | string | boolean | CommissionRateBundleValue;
  reason: string;
  requesterId: string;
  requesterEmail: string;
  requesterRole: string;
  createdAt: string;
  expiresAt: string;
}

export interface CommissionRateBundleValue {
  investorCommissionRateTotal: number;
  traderCommissionRate: number;
  appCommissionRate: number;
}
