'use strict';

// Routing / orchestration for Invoice afterSave (no real Parse posting).

jest.mock('../invoiceOrderFeePosting', () => ({
  postOrderInvoiceFees: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../invoiceServiceChargePosting', () => ({
  postServiceChargeInvoiceLedger: jest.fn().mockResolvedValue(undefined),
}));

const orderPosting = require('../invoiceOrderFeePosting');
const servicePosting = require('../invoiceServiceChargePosting');
const { invoiceAfterSave } = require('../invoiceTriggerAfterSave');

function makeRequest({ isNew, invoiceType, originalType }) {
  const invoice = {
    get(k) {
      if (k === 'invoiceType') return invoiceType;
      return undefined;
    },
  };
  const request = { object: invoice };
  if (!isNew) {
    request.original = {
      get(k) {
        if (k === 'invoiceType') return originalType;
        return undefined;
      },
    };
  }
  return request;
}

describe('invoiceAfterSave', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('new order invoice calls postOrderInvoiceFees only', async () => {
    await invoiceAfterSave(makeRequest({
      isNew: true,
      invoiceType: 'order',
    }));
    expect(orderPosting.postOrderInvoiceFees).toHaveBeenCalledTimes(1);
    expect(servicePosting.postServiceChargeInvoiceLedger).not.toHaveBeenCalled();
  });

  test('new app_service_charge calls postServiceChargeInvoiceLedger only', async () => {
    await invoiceAfterSave(makeRequest({
      isNew: true,
      invoiceType: 'app_service_charge',
    }));
    expect(servicePosting.postServiceChargeInvoiceLedger).toHaveBeenCalledTimes(1);
    expect(orderPosting.postOrderInvoiceFees).not.toHaveBeenCalled();
  });

  test('update with unchanged invoiceType does nothing', async () => {
    await invoiceAfterSave(makeRequest({
      isNew: false,
      invoiceType: 'order',
      originalType: 'order',
    }));
    expect(orderPosting.postOrderInvoiceFees).not.toHaveBeenCalled();
    expect(servicePosting.postServiceChargeInvoiceLedger).not.toHaveBeenCalled();
  });

  test('update with invoiceType change to order posts order fees', async () => {
    await invoiceAfterSave(makeRequest({
      isNew: false,
      invoiceType: 'order',
      originalType: 'draft',
    }));
    expect(orderPosting.postOrderInvoiceFees).toHaveBeenCalledTimes(1);
    expect(servicePosting.postServiceChargeInvoiceLedger).not.toHaveBeenCalled();
  });

  test('non-order non-service invoice type does nothing', async () => {
    await invoiceAfterSave(makeRequest({
      isNew: true,
      invoiceType: 'other',
    }));
    expect(orderPosting.postOrderInvoiceFees).not.toHaveBeenCalled();
    expect(servicePosting.postServiceChargeInvoiceLedger).not.toHaveBeenCalled();
  });
});
