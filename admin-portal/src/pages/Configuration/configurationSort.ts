import type { ConfigurationParameter } from './types';

export type ConfigParameterEntry = [string, Omit<ConfigurationParameter, 'value'>];

/** German A–Z by `displayName` (case- and accent-insensitive). */
export function sortFinancialConfigEntries(entries: ConfigParameterEntry[]): ConfigParameterEntry[] {
  return sortConfigEntriesAlphabetically(entries);
}

/** German A–Z by `displayName` (case- and accent-insensitive). */
export function sortConfigEntriesAlphabetically(entries: ConfigParameterEntry[]): ConfigParameterEntry[] {
  return [...entries].sort(([, a], [, b]) =>
    a.displayName.localeCompare(b.displayName, 'de', { sensitivity: 'base' }),
  );
}

/** Fixed display order for Steuerparameter (not alphabetical). */
const TAX_PARAMETER_DISPLAY_ORDER: Record<string, number> = {
  vatRate: 0,
  taxCollectionMode: 1,
  withholdingTaxRate: 2,
  solidaritySurchargeRate: 3,
};

export function sortTaxConfigEntries(entries: ConfigParameterEntry[]): ConfigParameterEntry[] {
  return [...entries].sort(([a], [b]) => (TAX_PARAMETER_DISPLAY_ORDER[a] ?? 99) - (TAX_PARAMETER_DISPLAY_ORDER[b] ?? 99));
}
