'use strict';

// Characterization tests for order-invoice AppLedger pairs (ADR-010).

jest.mock('../../../utils/accountingHelper/journal', () => ({
  postLedgerPair: jest.fn().mockResolvedValue([]),
}));

const { postLedgerPair } = require('../../../utils/accountingHelper/journal');
const { postOrderInvoiceFees } = require('../invoiceOrderFeePosting');

function makeInvoice(overrides = {}) {
  const attrs = Object.assign({
    id: 'inv-ord-1',
    invoiceType: 'order',
    invoiceNumber: 'ORD-2026-0001',
    userId: 'trader-a',
    customerId: 'trader-a',
    customerName: 'Trader A',
    orderId: 'order-42',
    businessCaseId: 'bc-9',
    feeBreakdown: {},
  }, overrides);
  return {
    id: attrs.id,
    get(k) {
      return attrs[k];
    },
  };
}

describe('postOrderInvoiceFees', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns without calls when feeBreakdown is empty', async () => {
    await postOrderInvoiceFees(makeInvoice({ feeBreakdown: {} }));
    expect(postLedgerPair).not.toHaveBeenCalled();
  });

  test('returns without calls when all fee components are zero or non-finite', async () => {
    await postOrderInvoiceFees(makeInvoice({
      feeBreakdown: { orderFee: 0, exchangeFee: 'x', foreignCosts: -1 },
    }));
    expect(postLedgerPair).not.toHaveBeenCalled();
  });

  test('posts one pair for a single positive orderFee', async () => {
    await postOrderInvoiceFees(makeInvoice({
      feeBreakdown: { orderFee: 12.5 },
    }));
    expect(postLedgerPair).toHaveBeenCalledTimes(1);
    expect(postLedgerPair).toHaveBeenCalledWith(expect.objectContaining({
      debitAccount: 'CLT-LIAB-AVA',
      creditAccount: 'PLT-REV-ORD',
      amount: 12.5,
      userId: 'trader-a',
      userRole: 'trader',
      transactionType: 'orderFee',
      referenceId: 'order-42',
      referenceType: 'Order',
      leg: 'order_fee:orderFee',
      metadata: expect.objectContaining({
        invoiceId: 'inv-ord-1',
        invoiceNumber: 'ORD-2026-0001',
        orderId: 'order-42',
        businessCaseId: 'bc-9',
        feeComponent: 'orderFee',
        referenceDocumentNumber: 'ORD-2026-0001',
      }),
    }));
  });

  test('posts three pairs when all components are positive', async () => {
    await postOrderInvoiceFees(makeInvoice({
      feeBreakdown: {
        orderFee: 1,
        exchangeFee: 2,
        foreignCosts: 3,
      },
    }));
    expect(postLedgerPair).toHaveBeenCalledTimes(3);
    const legs = postLedgerPair.mock.calls.map((c) => c[0].leg);
    expect(legs).toEqual([
      'order_fee:orderFee',
      'order_fee:exchangeFee',
      'order_fee:foreignCosts',
    ]);
    expect(postLedgerPair.mock.calls[0][0].creditAccount).toBe('PLT-REV-ORD');
    expect(postLedgerPair.mock.calls[1][0].creditAccount).toBe('PLT-REV-EXC');
    expect(postLedgerPair.mock.calls[2][0].creditAccount).toBe('PLT-REV-FRG');
  });

  test('uses invoice.id as referenceId when orderId is missing', async () => {
    await postOrderInvoiceFees(makeInvoice({
      orderId: undefined,
      feeBreakdown: { orderFee: 5 },
    }));
    expect(postLedgerPair).toHaveBeenCalledWith(expect.objectContaining({
      referenceId: 'inv-ord-1',
    }));
  });

  test('uses customerId when userId is missing', async () => {
    await postOrderInvoiceFees(makeInvoice({
      userId: undefined,
      customerId: 'cust-z',
      feeBreakdown: { orderFee: 1 },
    }));
    expect(postLedgerPair).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'cust-z',
    }));
  });
});
