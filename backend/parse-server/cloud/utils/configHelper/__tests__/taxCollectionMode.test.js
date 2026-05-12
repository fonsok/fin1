'use strict';

const {
  TAX_COLLECTION_MODES,
  normalizeTaxCollectionMode,
  isValidTaxCollectionMode,
} = require('../taxCollectionMode');

describe('taxCollectionMode helper', () => {
  test('normalizes invalid and missing values to customer_self_reports', () => {
    expect(normalizeTaxCollectionMode(undefined)).toBe(TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS);
    expect(normalizeTaxCollectionMode(null)).toBe(TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS);
    expect(normalizeTaxCollectionMode('unexpected')).toBe(TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS);
  });

  test('keeps platform_withholds as-is', () => {
    expect(normalizeTaxCollectionMode('platform_withholds')).toBe(TAX_COLLECTION_MODES.APP_WITHHOLDS);
  });

  test('validates both supported enum values only', () => {
    expect(isValidTaxCollectionMode('platform_withholds')).toBe(true);
    expect(isValidTaxCollectionMode('customer_self_reports')).toBe(true);
    expect(isValidTaxCollectionMode('wrong')).toBe(false);
  });
});
