'use strict';

// ADR-007 Phase-2 backend stub: `bookAppServiceCharge` Cloud function.
// Creates a platform-service-charge Invoice on the server idempotently. The
// existing `afterSave Invoice` trigger handles the AppLedger / BankContra
// postings, which is why those are NOT re-tested here.

describe('bookAppServiceCharge (ADR-007 Phase 2 backend stub)', () => {
  const cloudFunctions = {};

  const investorUser = {
    id: 'user-1',
    get(key) {
      if (key === 'email' || key === 'username') return 'investor@example.test';
      if (key === 'stableId') return 'user:investor@example.test';
      return null;
    },
  };

  const otherUser = {
    id: 'user-2',
    get(key) {
      if (key === 'email') return 'someone-else@example.test';
      return null;
    },
  };

  let savedInvoices;
  let investmentRow;
  let existingInvoiceRow;

  function makeInvestment(overrides = {}) {
    const base = {
      id: 'inv-1',
      className: 'Investment',
      attrs: {
        investorId: 'user-1',
        batchId: 'batch-1',
        serviceChargeAmount: 50,
        serviceChargeVat: 9.5,
        serviceChargeTotal: 59.5,
        serviceChargeRate: 0.05,
        investmentNumber: 'INV-001',
      },
    };
    Object.assign(base.attrs, overrides);
    return {
      ...base,
      get(key) { return this.attrs[key]; },
    };
  }

  class FakeQuery {
    constructor(classNameOrClass) {
      this.className = typeof classNameOrClass === 'string'
        ? classNameOrClass
        : (classNameOrClass && classNameOrClass.__fakeClassName) || 'Unknown';
      this.filters = {};
    }
    equalTo(field, value) { this.filters[field] = value; return this; }
    async first() {
      if (this.className === 'Invoice') {
        if (existingInvoiceRow
          && this.filters.batchId === existingInvoiceRow.batchId
          && this.filters.invoiceType === 'service_charge') {
          return existingInvoiceRow;
        }
        return undefined;
      }
      return undefined;
    }
    async get(id) {
      if (this.className === 'Investment' && investmentRow && investmentRow.id === id) {
        return investmentRow;
      }
      throw new global.Parse.Error(101, 'Object not found');
    }
  }

  class FakeInvoice {
    constructor() {
      this.attrs = {};
      this.id = undefined;
    }
    set(key, value) { this.attrs[key] = value; }
    async save() {
      this.id = 'invoice-' + (savedInvoices.length + 1);
      savedInvoices.push(this);
      return this;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((key) => delete cloudFunctions[key]);
    savedInvoices = [];
    investmentRow = makeInvestment();
    existingInvoiceRow = null;

    const ParseObject = {
      extend(className) {
        if (className === 'Invoice') {
          FakeInvoice.__fakeClassName = 'Invoice';
          return FakeInvoice;
        }
        const Noop = class {
          constructor() { this.className = className; this.attrs = {}; }
          set(k, v) { this.attrs[k] = v; }
        };
        Noop.__fakeClassName = className;
        return Noop;
      },
    };

    global.Parse = {
      Object: ParseObject,
      Cloud: {
        define(name, fn) {
          cloudFunctions[name] = fn;
        },
        run: jest.fn(),
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    // Codes used by the function under test
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.INVALID_VALUE = 142;
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    // Silence the unrelated console.warn paths when wallet is disabled
    jest.spyOn(console, 'warn').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});

    // eslint-disable-next-line global-require
    require('../investment');
  });

  test('creates a service_charge Invoice when called by the investor', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    const result = await handler({ user: investorUser, params: { investmentId: 'inv-1' } });

    expect(result.success).toBe(true);
    expect(result.skipped).toBe(false);
    expect(savedInvoices).toHaveLength(1);
    const invoice = savedInvoices[0];
    expect(invoice.attrs.invoiceType).toBe('service_charge');
    expect(invoice.attrs.investmentId).toBe('inv-1');
    expect(invoice.attrs.batchId).toBe('batch-1');
    expect(invoice.attrs.customerId).toBe('user-1');
    // ADR-007 Phase 2 consistency contract: `userId` must mirror the investor
    // so the `afterSave Invoice` trigger groups BankContraPostings with the
    // investor's other activity. `investmentIds` is set so downstream reports
    // can join back to Investment docs.
    expect(invoice.attrs.userId).toBe('user-1');
    expect(invoice.attrs.investmentIds).toEqual(['inv-1']);
    expect(invoice.attrs.subtotal).toBeCloseTo(50, 2);
    expect(invoice.attrs.taxAmount).toBeCloseTo(9.5, 2);
    expect(invoice.attrs.totalAmount).toBeCloseTo(59.5, 2);
    expect(invoice.attrs.source).toBe('backend');
    expect(invoice.attrs.metadata.adrRef).toBe('ADR-007-Phase-2');
  });

  test('is idempotent: second call short-circuits when an Invoice already exists', async () => {
    existingInvoiceRow = {
      id: 'invoice-existing',
      batchId: 'batch-1',
      invoiceType: 'service_charge',
    };
    const handler = cloudFunctions.bookAppServiceCharge;
    const result = await handler({ user: investorUser, params: { investmentId: 'inv-1' } });

    expect(result.success).toBe(true);
    expect(result.skipped).toBe(true);
    expect(result.reason).toBe('already booked');
    expect(result.invoiceId).toBe('invoice-existing');
    expect(savedInvoices).toHaveLength(0);
  });

  test('rejects when an unrelated user tries to book the Invoice for someone else', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    await expect(
      handler({ user: otherUser, params: { investmentId: 'inv-1' } })
    ).rejects.toThrow(/Vorgang nicht erlaubt/);
    expect(savedInvoices).toHaveLength(0);
  });

  test('skips gracefully when the Investment has no service charge', async () => {
    investmentRow = makeInvestment({
      serviceChargeAmount: 0,
      serviceChargeVat: 0,
      serviceChargeTotal: 0,
    });
    const handler = cloudFunctions.bookAppServiceCharge;
    const result = await handler({ user: investorUser, params: { investmentId: 'inv-1' } });
    expect(result.success).toBe(true);
    expect(result.skipped).toBe(true);
    expect(result.reason).toBe('no service charge');
    expect(savedInvoices).toHaveLength(0);
  });

  test('accepts master-key calls without a user session', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    const result = await handler({ master: true, params: { investmentId: 'inv-1' } });
    expect(result.success).toBe(true);
    expect(savedInvoices).toHaveLength(1);
  });

  test('is independent from later investment status changes', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    const first = await handler({ user: investorUser, params: { investmentId: 'inv-1' } });
    expect(first.success).toBe(true);
    expect(first.skipped).toBe(false);
    expect(savedInvoices).toHaveLength(1);

    existingInvoiceRow = {
      id: savedInvoices[0].id,
      batchId: 'batch-1',
      invoiceType: 'service_charge',
    };
    investmentRow.attrs.status = 'cancelled';
    const second = await handler({ user: investorUser, params: { investmentId: 'inv-1' } });
    expect(second.success).toBe(true);
    expect(second.skipped).toBe(true);
    expect(second.invoiceId).toBe(savedInvoices[0].id);
    expect(savedInvoices).toHaveLength(1);
  });

  test('requires investmentId', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    await expect(
      handler({ user: investorUser, params: {} })
    ).rejects.toThrow(/investmentId/);
  });
});
