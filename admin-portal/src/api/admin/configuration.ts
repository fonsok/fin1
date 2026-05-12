import { cloudFunction } from '../parse';
import type { ConfigurationResponse, PendingConfigChange } from './types';

/** Get system configuration */
export async function getConfiguration(): Promise<ConfigurationResponse> {
  return cloudFunction('getConfiguration');
}

/** Get pending configuration changes */
export async function getPendingConfigurationChanges(): Promise<{
  requests: PendingConfigChange[];
  total: number;
}> {
  return cloudFunction('getPendingConfigurationChanges');
}

/** Request a configuration change (may require 4-eyes approval) */
export async function requestConfigurationChange(params: {
  parameterName: string;
  newValue: number | boolean | string;
  reason: string;
}): Promise<{
  success: boolean;
  requiresApproval: boolean;
  fourEyesRequestId?: string;
  message: string;
}> {
  return cloudFunction('requestConfigurationChange', params);
}

/** Approve a configuration change */
export async function approveConfigurationChange(
  requestId: string,
  notes?: string,
): Promise<{ success: boolean }> {
  return cloudFunction('approveConfigurationChange', { requestId, notes });
}

/** Reject a configuration change */
export async function rejectConfigurationChange(
  requestId: string,
  reason: string,
): Promise<{ success: boolean }> {
  return cloudFunction('rejectConfigurationChange', { requestId, reason });
}
