'use strict';

// Golden-style checks for net/VAT split, BankContraPosting + AppLedger triple.

jest.mock('../../../utils/accountingHelper/documents', () => ({
  ensureServiceChargeInvoiceDocument: jest.fn().mockResolvedValue(null),
}));

const documents = require('../../../utils/accountingHelper/documents');
const { postServiceChargeInvoiceLedger } = require('../invoiceServiceChargePosting');

function makeInvoice(overrides = {}) {
  const attrs = Object.assign({
    id: 'inv-sc-1',
    userId: 'inv-u1',
    customerName: 'Investor One',
    batchId: 'batch-77',
    invoiceNumber: 'SC-2026-0000001',
    investmentIds: ['inv-1'],
    businessCaseId: 'bc-sc',
    createdAt: new Date('2026-03-01T10:00:00Z'),
    totalAmount: 119,
    subtotal: 100,
    taxAmount: 19,
    taxRate: 19,
  }, overrides);
  return {
    id: attrs.id,
    get(k) {
      return attrs[k];
    },
  };
}

describe('postServiceChargeInvoiceLedger', () => {
  let saveAllCalls;

  beforeEach(() => {
    jest.clearAllMocks();
    documents.ensureServiceChargeInvoiceDocument.mockResolvedValue(null);
    saveAllCalls = [];

    class FakeRow {
      constructor() {
        this.attrs = {};
        this.id = undefined;
      }
      set(k, v) {
        this.attrs[k] = v;
      }
      get(k) {
        return this.attrs[k];
      }
    }

    global.Parse = {
      Object: {
        extend(className) {
          if (className === 'BankContraPosting') {
            FakeRow.__name = 'BankContraPosting';
            return FakeRow;
          }
          if (className === 'AppLedgerEntry') {
            FakeRow.__name = 'AppLedgerEntry';
            return FakeRow;
          }
          throw new Error(`Unexpected extend(${className})`);
        },
        async saveAll(rows, opts) {
          saveAllCalls.push({ rows, opts });
          rows.forEach((row, i) => {
            if (!row.id) row.id = `saved-${saveAllCalls.length}-${i}`;
          });
        },
      },
    };
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    delete global.Parse;
  });

  test('no-op when gross amount is zero', async () => {
    await postServiceChargeInvoiceLedger(makeInvoice({
      totalAmount: 0,
      subtotal: 0,
      taxAmount: 0,
    }));
    expect(saveAllCalls).toHaveLength(0);
  });

  test('explicit taxAmount and subtotal/total: net 100 VAT 19 gross 119', async () => {
    await postServiceChargeInvoiceLedger(makeInvoice({
      totalAmount: 119,
      subtotal: 100,
      taxAmount: 19,
    }));
    expect(saveAllCalls).toHaveLength(2);
    const [bankBatch, ledgerBatch] = saveAllCalls;
    expect(bankBatch.rows).toHaveLength(2);
    expect(ledgerBatch.rows).toHaveLength(3);

    const netBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'net');
    const vatBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'vat');
    expect(netBcp.get('amount')).toBe(100);
    expect(vatBcp.get('amount')).toBe(19);

    const liability = ledgerBatch.rows.find((r) => r.get('account') === 'CLT-LIAB-AVA');
    expect(liability.get('side')).toBe('debit');
    expect(liability.get('amount')).toBe(119);
  });

  test('taxAmount zero but total > subtotal derives VAT from difference', async () => {
    await postServiceChargeInvoiceLedger(makeInvoice({
      totalAmount: 119,
      subtotal: 100,
      taxAmount: 0,
    }));
    expect(saveAllCalls).toHaveLength(2);
    const bankBatch = saveAllCalls[0];
    const netBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'net');
    const vatBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'vat');
    expect(netBcp.get('amount')).toBe(100);
    expect(vatBcp.get('amount')).toBe(19);
  });

  test('taxAmount zero and total not above subtotal derives VAT from gross / (1 + rate)', async () => {
    await postServiceChargeInvoiceLedger(makeInvoice({
      totalAmount: 119,
      subtotal: 119,
      taxAmount: 0,
      taxRate: 19,
    }));
    expect(saveAllCalls).toHaveLength(2);
    const bankBatch = saveAllCalls[0];
    const netBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'net');
    const vatBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'vat');
    expect(netBcp.get('amount')).toBe(100);
    expect(vatBcp.get('amount')).toBe(19);
    const liability = saveAllCalls[1].rows.find((r) => r.get('account') === 'CLT-LIAB-AVA');
    expect(liability.get('amount')).toBe(119);
  });

  test('uses subtotal as gross when totalAmount missing', async () => {
    await postServiceChargeInvoiceLedger(makeInvoice({
      totalAmount: undefined,
      subtotal: 119,
      taxAmount: 19,
    }));
    const bankBatch = saveAllCalls[0];
    const netBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'net');
    const vatBcp = bankBatch.rows.find((r) => r.get('metadata').component === 'vat');
    expect(netBcp.get('amount') + vatBcp.get('amount')).toBeCloseTo(119, 2);
  });

  test('passes referenceDocumentId when document helper returns an id', async () => {
    documents.ensureServiceChargeInvoiceDocument.mockResolvedValue({ id: 'doc-ref-1' });
    await postServiceChargeInvoiceLedger(makeInvoice({
      totalAmount: 119,
      subtotal: 100,
      taxAmount: 19,
    }));
    const liability = saveAllCalls[1].rows.find((r) => r.get('account') === 'CLT-LIAB-AVA');
    expect(liability.get('metadata').referenceDocumentId).toBe('doc-ref-1');
  });
});
