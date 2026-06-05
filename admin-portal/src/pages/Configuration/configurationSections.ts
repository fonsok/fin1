import { PARAMETER_DEFINITIONS } from './parameterDefinitions';
import type { PendingConfigChange } from './types';

export const CONFIG_SECTION = {
  financial: 'financial',
  tax: 'tax',
  system: 'system',
  display: 'display',
} as const;

export type ConfigSectionId = (typeof CONFIG_SECTION)[keyof typeof CONFIG_SECTION];

export function getConfigSectionForParameter(paramKey: string): ConfigSectionId | null {
  const def = PARAMETER_DEFINITIONS[paramKey];
  if (!def) return null;
  switch (def.category) {
    case 'financial':
      return CONFIG_SECTION.financial;
    case 'tax':
      return CONFIG_SECTION.tax;
    case 'system':
      return CONFIG_SECTION.system;
    case 'display':
      return CONFIG_SECTION.display;
    default:
      return null;
  }
}

export function countPendingInSection(
  requests: PendingConfigChange[] | undefined,
  paramKeys: readonly string[],
): number {
  if (!requests?.length || paramKeys.length === 0) return 0;
  const keySet = new Set(paramKeys);
  return requests.filter((r) => keySet.has(r.parameterName)).length;
}
