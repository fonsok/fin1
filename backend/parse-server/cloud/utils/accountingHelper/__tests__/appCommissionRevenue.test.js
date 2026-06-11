'use strict';

jest.mock('../journal', () => ({
  postLedgerPair: jest.fn().mockResolvedValue([]),
}));

jest.mock('../documents', () => ({
  createAppCommissionEigenbeleg: jest.fn(),
}));

jest.mock('../documentReferenceResolver', () => ({
  resolveDocumentReference: jest.fn().mockReturnValue({
    referenceDocumentId: 'eap-1',
    referenceDocumentNumber: 'EAP-2026-0000001',
  }),
}));

const { postLedgerPair } = require('../journal');
const { createAppCommissionEigenbeleg } = require('../documents');
const { bookAppCommissionRevenueIfDue } = require('../settlementCore/appCommissionRevenue');

describe('bookAppCommissionRevenueIfDue', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAppCommissionEigenbeleg.mockResolvedValue({
      id: 'eap-1',
      get: (k) => (k === 'accountingDocumentNumber' ? 'EAP-2026-0000001' : undefined),
    });
  });

  test('creates eigenbeleg before GL pair with document reference', async () => {
    await bookAppCommissionRevenueIfDue({
      totalAppCommission: 10,
      tradeId: 'trade-1',
      tradeNumber: 7,
      traderId: 'trader-1',
      appCommissionRate: 0.05,
      grossProfitBasis: 200,
      businessCaseId: 'bc-1',
    });

    expect(createAppCommissionEigenbeleg).toHaveBeenCalled();
    expect(postLedgerPair).toHaveBeenCalledWith(
      expect.objectContaining({
        transactionType: 'appCommission',
        leg: 'app_commission',
        metadata: expect.objectContaining({
          referenceDocumentId: 'eap-1',
          referenceDocumentNumber: 'EAP-2026-0000001',
        }),
      }),
    );
  });

  test('skips when commission is zero', async () => {
    const out = await bookAppCommissionRevenueIfDue({
      totalAppCommission: 0,
      tradeId: 'trade-1',
    });
    expect(out).toBeNull();
    expect(createAppCommissionEigenbeleg).not.toHaveBeenCalled();
  });
});
