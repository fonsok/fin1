'use strict';

const TAX_COLLECTION_MODES = Object.freeze({
  APP_WITHHOLDS: 'platform_withholds',
  CUSTOMER_SELF_REPORTS: 'customer_self_reports',
});

const TAX_COLLECTION_MODE_VALUES = Object.freeze([
  TAX_COLLECTION_MODES.APP_WITHHOLDS,
  TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS,
]);

function normalizeTaxCollectionMode(value) {
  return value === TAX_COLLECTION_MODES.APP_WITHHOLDS
    ? TAX_COLLECTION_MODES.APP_WITHHOLDS
    : TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS;
}

function isValidTaxCollectionMode(value) {
  return value === TAX_COLLECTION_MODES.APP_WITHHOLDS
    || value === TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS;
}

module.exports = {
  TAX_COLLECTION_MODES,
  TAX_COLLECTION_MODE_VALUES,
  normalizeTaxCollectionMode,
  isValidTaxCollectionMode,
};
