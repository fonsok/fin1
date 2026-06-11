import { describe, expect, it } from 'vitest';
import catalog from '../../../../../shared/contracts/appLedgerTransactionTypes.json';
import {
  APP_LEDGER_TRANSACTION_TYPE_KEYS,
  transactionTypeDisplayLabel,
  TRANSACTION_TYPE_LABELS,
  resolveCanonicalTransactionTypeKey,
} from './transactionTypes';

describe('transactionTypes (SSOT contract)', () => {
  it('loads canonical keys from shared contract', () => {
    expect(APP_LEDGER_TRANSACTION_TYPE_KEYS).toEqual(catalog.canonicalTypes.map((entry) => entry.key));
  });

  it('maps canonical transaction types', () => {
    expect(transactionTypeDisplayLabel('appServiceCharge')).toBe('Appgebühr');
    expect(transactionTypeDisplayLabel('orderFee')).toBe('Ordergebühr');
    expect(transactionTypeDisplayLabel('appCommission')).toBe('Erfolgsprovision Plattform (8400)');
    expect(transactionTypeDisplayLabel('commission')).toBe('Provision Clearing (Investor/Trader, 1700)');
  });

  it('maps legacy platformServiceCharge to Appgebühr', () => {
    expect(transactionTypeDisplayLabel('platformServiceCharge')).toBe('Appgebühr');
    expect(resolveCanonicalTransactionTypeKey('platformServiceCharge')).toBe('appServiceCharge');
  });

  it('falls back to raw type when unknown', () => {
    expect(transactionTypeDisplayLabel('customType')).toBe('customType');
  });

  it('does not duplicate Appgebühr in filter options', () => {
    const appFeeOptions = Object.entries(TRANSACTION_TYPE_LABELS).filter(([, label]) => label === 'Appgebühr');
    expect(appFeeOptions).toHaveLength(1);
    expect(appFeeOptions[0][0]).toBe('appServiceCharge');
  });
});
