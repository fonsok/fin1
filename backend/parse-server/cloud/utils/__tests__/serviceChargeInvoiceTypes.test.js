'use strict';

const {
  isServiceChargeInvoiceType,
  serviceChargeInvoiceTypesForDuplicateQuery,
} = require('../serviceChargeInvoiceTypes');

describe('serviceChargeInvoiceTypes', () => {
  it('treats service_charge, app_service_charge, and legacy platform as family', () => {
    expect(isServiceChargeInvoiceType('service_charge')).toBe(true);
    expect(isServiceChargeInvoiceType('app_service_charge')).toBe(true);
    expect(isServiceChargeInvoiceType('platform_service_charge')).toBe(true);
    expect(isServiceChargeInvoiceType('order')).toBe(false);
  });

  it('exposes duplicate-query list including all family members', () => {
    const list = serviceChargeInvoiceTypesForDuplicateQuery();
    expect(list).toEqual(
      expect.arrayContaining(['service_charge', 'app_service_charge', 'platform_service_charge'])
    );
  });
});
