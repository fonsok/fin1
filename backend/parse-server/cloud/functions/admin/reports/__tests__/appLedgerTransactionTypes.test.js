'use strict';

const catalog = require('../../../../contracts/appLedgerTransactionTypes.json');
const {
  ADMIN_TRANSACTION_TYPE_LABELS,
  CANONICAL_TRANSACTION_TYPE_KEYS,
  LEGACY_TRANSACTION_TYPE_LABEL_KEYS,
  resolveCanonicalTransactionTypeKey,
  isKnownAppLedgerTransactionType,
  TRANSACTION_TYPE_APP_SERVICE_CHARGE,
  LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD,
} = require('../appLedgerTransactionTypes');

describe('appLedgerTransactionTypes (SSOT contract)', () => {
  test('loads canonical keys from shared JSON', () => {
    expect(CANONICAL_TRANSACTION_TYPE_KEYS).toEqual(catalog.canonicalTypes.map((entry) => entry.key));
  });

  test('maps legacy app service charge alias', () => {
    expect(LEGACY_TRANSACTION_TYPE_APP_SERVICE_CHARGE_OLD).toBe('platformServiceCharge');
    expect(TRANSACTION_TYPE_APP_SERVICE_CHARGE).toBe('appServiceCharge');
    expect(resolveCanonicalTransactionTypeKey('platformServiceCharge')).toBe('appServiceCharge');
    expect(LEGACY_TRANSACTION_TYPE_LABEL_KEYS.platformServiceCharge).toBe('appServiceCharge');
  });

  test('labels cover all canonical keys', () => {
    for (const key of CANONICAL_TRANSACTION_TYPE_KEYS) {
      expect(typeof ADMIN_TRANSACTION_TYPE_LABELS[key]).toBe('string');
      expect(ADMIN_TRANSACTION_TYPE_LABELS[key].length).toBeGreaterThan(0);
    }
  });

  test('recognizes canonical and legacy types', () => {
    expect(isKnownAppLedgerTransactionType('orderFee')).toBe(true);
    expect(isKnownAppLedgerTransactionType('platformServiceCharge')).toBe(true);
    expect(isKnownAppLedgerTransactionType('unknownType')).toBe(false);
  });
});
