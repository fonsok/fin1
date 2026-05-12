// Configuration types

export interface ConfigurationParameter {
  key: string;
  value: number | string | boolean;
  displayName: string;
  description: string;
  type: 'number' | 'percentage' | 'percent_display' | 'currency' | 'boolean' | 'string';
  category: 'financial' | 'tax' | 'display' | 'system' | 'feature';
  isCritical: boolean;
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
  oldValue: number | string | boolean;
  newValue: number | string | boolean;
  reason: string;
  requesterId: string;
  requesterEmail: string;
  requesterRole: string;
  createdAt: string;
  expiresAt: string;
}
