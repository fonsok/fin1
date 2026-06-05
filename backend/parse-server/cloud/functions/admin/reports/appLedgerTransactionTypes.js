'use strict';

/** SSOT source: shared/contracts/appLedgerTransactionTypes.json (copied to cloud/contracts on deploy). */
const catalog = require('../../../contracts/appLedgerTransactionTypes.json');

const CANONICAL_TRANSACTION_TYPE_KEYS = catalog.canonicalTypes.map((entry) => entry.key);

const ADMIN_TRANSACTION_TYPE_LABELS = Object.fromEntries(
  catalog.canonicalTypes.map((entry) => [entry.key, entry.labelDe]),
);

const LEGACY_TRANSACTION_TYPE_LABEL_KEYS = { ...catalog.legacyLabelKeys };

const TRANSACTION_TYPE_APP_SERVICE_CHARGE = 'appServiceCharge';
const LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD = 'platformServiceCharge';

function resolveCanonicalTransactionTypeKey(rawType) {
  const key = String(rawType || '').trim();
  if (!key) return '';
  return LEGACY_TRANSACTION_TYPE_LABEL_KEYS[key] || key;
}

function isKnownAppLedgerTransactionType(rawType) {
  const canonical = resolveCanonicalTransactionTypeKey(rawType);
  return CANONICAL_TRANSACTION_TYPE_KEYS.includes(canonical);
}

module.exports = {
  CANONICAL_TRANSACTION_TYPE_KEYS,
  ADMIN_TRANSACTION_TYPE_LABELS,
  LEGACY_TRANSACTION_TYPE_LABEL_KEYS,
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
  resolveCanonicalTransactionTypeKey,
  isKnownAppLedgerTransactionType,
};
