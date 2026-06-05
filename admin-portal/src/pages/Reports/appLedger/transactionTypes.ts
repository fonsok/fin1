import catalog from '../../../../../shared/contracts/appLedgerTransactionTypes.json';

export type AppLedgerTransactionTypeKey = (typeof catalog.canonicalTypes)[number]['key'];

const LEGACY_TRANSACTION_TYPE_LABEL_KEYS: Record<string, AppLedgerTransactionTypeKey> = {
  ...(catalog.legacyLabelKeys as Record<string, AppLedgerTransactionTypeKey>),
};

/** Canonical filter/display keys → German admin labels (SSOT: shared/contracts). */
export const TRANSACTION_TYPE_LABELS: Record<AppLedgerTransactionTypeKey, string> = Object.fromEntries(
  catalog.canonicalTypes.map((entry) => [entry.key, entry.labelDe]),
) as Record<AppLedgerTransactionTypeKey, string>;

export const APP_LEDGER_TRANSACTION_TYPE_KEYS = catalog.canonicalTypes.map(
  (entry) => entry.key,
) as AppLedgerTransactionTypeKey[];

export function transactionTypeDisplayLabel(transactionType: string): string {
  const labelKey = LEGACY_TRANSACTION_TYPE_LABEL_KEYS[transactionType] ?? transactionType;
  return TRANSACTION_TYPE_LABELS[labelKey as AppLedgerTransactionTypeKey] ?? transactionType;
}

export function resolveCanonicalTransactionTypeKey(rawType: string): string {
  const key = rawType.trim();
  if (!key) return '';
  return LEGACY_TRANSACTION_TYPE_LABEL_KEYS[key] ?? key;
}
