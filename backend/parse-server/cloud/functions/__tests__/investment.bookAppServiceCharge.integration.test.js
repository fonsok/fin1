'use strict';

// ============================================================================
// ADR-007 Phase 2 – End-to-End regression lock.
// ============================================================================
//
// Exercises the *full* posting chain the backend now owns:
//
//   bookAppServiceCharge (Cloud fn)
//       └─► Invoice.save()
//               └─► afterSave Invoice trigger    ← triggers/invoice/
//                       ├─► BankContraPosting[net]   (BANK-PS-NET)
//                       ├─► BankContraPosting[vat]   (BANK-PS-VAT)
//                       └─► AppLedgerEntry × 3       (PLT-REV-PSC,
//                                                      PLT-TAX-VAT,
//                                                      CLT-LIAB-AVA)
//
// History: the Soll-side used to point at PLT-CLR-GEN (clearing) until ADR-007
// re-anchored it on CLT-LIAB-AVA so that the customer-liability sub-ledger
// stays in lockstep with the invoice and BankContra postings.
//
// This test guards the three bugs we fixed by hand in production on
// 2026-04-23 — regressions here would re-introduce them silently:
//
//   1. BankContraPosting.reference must be `PSC-${batchId}` (never
//      `PSC-${invoice.id}`, which is what the legacy fallback used to do).
//   2. BankContraPosting.investorId must equal `invoice.userId` (the
//      BankContra report groups by this field; an empty investorId made
//      those postings invisible in the admin UI).
//   3. BankContraPosting.investmentIds must contain the Investment id so
//      downstream reports can drill down from the posting.
//
// This file deliberately does not re-test the narrow unit behaviour of
// `bookAppServiceCharge` — that's covered by
// `investment.bookAppServiceCharge.test.js`. Keeping the integration
// fixture minimal makes regressions obvious.

describe('ADR-007 Phase 2 – full Invoice→posting chain (integration)', () => {
  const cloudFunctions = {};
  const afterSaveTriggers = {};
  const beforeSaveTriggers = {};

  const investorUser = {
    id: 'user-1',
    get(key) {
      if (key === 'email' || key === 'username') return 'investor@example.test';
      if (key === 'stableId') return 'user:investor@example.test';
      return null;
    },
  };

  let savedInvoices;
  let savedBankContraPostings;
  let savedAppLedgerEntries;
  let investmentRow;
  let existingInvoiceRow;

  function makeInvestment(overrides = {}) {
    const base = {
      id: 'inv-42',
      className: 'Investment',
      attrs: {
        investorId: 'user-1',
        investorName: 'Max Fischer',
        batchId: 'batch-42',
        serviceChargeAmount: 50,
        serviceChargeVat: 9.5,
        serviceChargeTotal: 59.5,
        serviceChargeRate: 0.05,
        investmentNumber: 'INV-042',
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
      this._startsWith = null;
      this._descField = null;
      this._containedIn = null;
    }
    equalTo(field, value) { this.filters[field] = value; return this; }
    notEqualTo() { return this; }
    containedIn(field, values) {
      this._containedIn = { field, values: Array.isArray(values) ? values : [] };
      return this;
    }
    startsWith(field, value) {
      this._startsWith = { field, value };
      return this;
    }
    descending(field) {
      this._descField = field;
      return this;
    }
    limit() { return this; }
    async first() {
      if (this.className === 'Invoice' && this._startsWith && this._startsWith.field === 'invoiceNumber') {
        return undefined;
      }
      if (this.className === 'Invoice') {
        const batchMatch = existingInvoiceRow
          && this.filters.batchId === existingInvoiceRow.batchId;
        const typeOk = this._containedIn && this._containedIn.field === 'invoiceType'
          ? !!(existingInvoiceRow && this._containedIn.values.includes(existingInvoiceRow.invoiceType))
          : !!(existingInvoiceRow && this.filters.invoiceType === existingInvoiceRow.invoiceType);
        if (existingInvoiceRow && batchMatch && typeOk) {
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

  FakeQuery.or = (...parts) => ({
    limit() {
      return this;
    },
    async find() {
      for (const p of parts) {
        if (p && typeof p.first === 'function') {
          const hit = await p.first();
          if (hit) return [hit];
        }
      }
      return [];
    },
  });

  // `Invoice.save()` implicitly fires the `afterSave Invoice` trigger that we
  // loaded from `triggers/invoice/`. This is how the real Parse Server
  // behaves — the integration test mirrors it so regressions in the trigger
  // are caught immediately.
  class FakeInvoice {
    constructor() { this.attrs = {}; this.id = undefined; }
    set(key, value) { this.attrs[key] = value; }
    get(key) { return this.attrs[key]; }
    async save() {
      const beforeSave = beforeSaveTriggers.Invoice;
      if (beforeSave) {
        await beforeSave({ object: this, original: undefined });
      }
      this.id = 'invoice-' + (savedInvoices.length + 1);
      savedInvoices.push(this);
      const afterSave = afterSaveTriggers.Invoice;
      if (afterSave) {
        // `original` is undefined on a brand-new Invoice → matches the
        // production trigger's `isNew` guard.
        await afterSave({ object: this, original: undefined });
      }
      return this;
    }
  }

  class FakeBankContraPosting {
    constructor() { this.attrs = {}; this.id = undefined; }
    set(key, value) { this.attrs[key] = value; }
    get(key) { return this.attrs[key]; }
    async save() {
      this.id = 'bcp-' + (savedBankContraPostings.length + 1);
      savedBankContraPostings.push(this);
      return this;
    }
  }

  class FakeAppLedgerEntry {
    constructor() { this.attrs = {}; this.id = undefined; }
    set(key, value) { this.attrs[key] = value; }
    get(key) { return this.attrs[key]; }
    async save() {
      this.id = 'ale-' + (savedAppLedgerEntries.length + 1);
      savedAppLedgerEntries.push(this);
      return this;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((key) => delete cloudFunctions[key]);
    Object.keys(afterSaveTriggers).forEach((key) => delete afterSaveTriggers[key]);
    Object.keys(beforeSaveTriggers).forEach((key) => delete beforeSaveTriggers[key]);
    savedInvoices = [];
    savedBankContraPostings = [];
    savedAppLedgerEntries = [];
    investmentRow = makeInvestment();
    existingInvoiceRow = null;

    const ParseObject = {
      extend(className) {
        if (className === 'Invoice') {
          FakeInvoice.__fakeClassName = 'Invoice';
          return FakeInvoice;
        }
        if (className === 'BankContraPosting') {
          FakeBankContraPosting.__fakeClassName = 'BankContraPosting';
          return FakeBankContraPosting;
        }
        if (className === 'AppLedgerEntry') {
          FakeAppLedgerEntry.__fakeClassName = 'AppLedgerEntry';
          return FakeAppLedgerEntry;
        }
        const Noop = class {
          constructor() { this.className = className; this.attrs = {}; }
          set(k, v) { this.attrs[k] = v; }
        };
        Noop.__fakeClassName = className;
        return Noop;
      },
      async saveAll(objs) {
        for (const obj of objs) {
          // All our fake save() are async and self-assigning; just call them.
          // eslint-disable-next-line no-await-in-loop
          await obj.save();
        }
        return objs;
      },
    };

    global.Parse = {
      Object: ParseObject,
      Cloud: {
        define(name, fn) { cloudFunctions[name] = fn; },
        afterSave(className, fn) { afterSaveTriggers[className] = fn; },
        beforeSave(className, fn) { beforeSaveTriggers[className] = fn; },
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
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.INVALID_VALUE = 142;
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;
    global.Parse.Error.DUPLICATE_VALUE = 137;

    jest.spyOn(console, 'warn').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});

    // Load BOTH modules — in production, triggers/invoice/ is loaded via main.js
    // alongside functions/investment.js. Order matters here: we register
    // the afterSave trigger FIRST so the `FakeInvoice.save()` can dispatch
    // to it.
    // eslint-disable-next-line global-require
    require('../../triggers/invoice');
    // eslint-disable-next-line global-require
    require('../investment');
  });

  test('creates an Invoice AND the full BankContra + AppLedger posting set', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    const result = await handler({ user: investorUser, params: { investmentId: 'inv-42' } });

    expect(result.success).toBe(true);
    expect(result.skipped).toBe(false);
    expect(savedInvoices).toHaveLength(1);

    // --- BankContraPosting (the legacy bug-riddled path) -------------------
    expect(savedBankContraPostings).toHaveLength(2);
    const [netPosting, vatPosting] = savedBankContraPostings;

    // Regression #1: reference MUST use batchId, not invoice.id.
    expect(netPosting.attrs.reference).toBe('PSC-batch-42');
    expect(vatPosting.attrs.reference).toBe('PSC-batch-42');
    expect(netPosting.attrs.reference).not.toMatch(/PSC-invoice-/);

    // Regression #2: investorId must be non-empty and equal invoice.userId.
    expect(netPosting.attrs.investorId).toBe('user-1');
    expect(vatPosting.attrs.investorId).toBe('user-1');

    // Regression #3: investmentIds must round-trip from the invoice.
    expect(netPosting.attrs.investmentIds).toEqual(['inv-42']);
    expect(vatPosting.attrs.investmentIds).toEqual(['inv-42']);

    // Accounting contract: NET + VAT = totalAmount.
    expect(netPosting.attrs.account).toBe('BANK-PS-NET');
    expect(vatPosting.attrs.account).toBe('BANK-PS-VAT');
    expect(netPosting.attrs.amount).toBeCloseTo(50, 2);
    expect(vatPosting.attrs.amount).toBeCloseTo(9.5, 2);
    expect(netPosting.attrs.amount + vatPosting.attrs.amount).toBeCloseTo(59.5, 2);
    expect(netPosting.attrs.side).toBe('credit');
    expect(vatPosting.attrs.side).toBe('credit');
    expect(netPosting.attrs.batchId).toBe('batch-42');

    // --- AppLedgerEntry (double-entry booking) -----------------------------
    expect(savedAppLedgerEntries).toHaveLength(3);
    const accounts = savedAppLedgerEntries.map((e) => ({
      account: e.attrs.account,
      side: e.attrs.side,
      amount: e.attrs.amount,
    }));
    expect(accounts).toEqual(expect.arrayContaining([
      { account: 'PLT-REV-PSC', side: 'credit', amount: expect.closeTo(50, 2) },
      { account: 'PLT-TAX-VAT', side: 'credit', amount: expect.closeTo(9.5, 2) },
      { account: 'CLT-LIAB-AVA', side: 'debit', amount: expect.closeTo(59.5, 2) },
    ]));

    // Double-entry invariant: sum(debit) === sum(credit).
    const debitSum = savedAppLedgerEntries
      .filter((e) => e.attrs.side === 'debit')
      .reduce((acc, e) => acc + e.attrs.amount, 0);
    const creditSum = savedAppLedgerEntries
      .filter((e) => e.attrs.side === 'credit')
      .reduce((acc, e) => acc + e.attrs.amount, 0);
    expect(debitSum).toBeCloseTo(creditSum, 2);

    // All AppLedger entries must reference the batchId, never the invoice.id.
    for (const entry of savedAppLedgerEntries) {
      expect(entry.attrs.referenceId).toBe('batch-42');
      expect(entry.attrs.referenceType).toBe('investment_batch');
      expect(entry.attrs.userId).toBe('user-1');
    }

    expect(savedInvoices[0].get('invoiceNumber') || '').toMatch(/^SC-\d{4}-\d{7}$/);
    const revMeta = savedAppLedgerEntries.find((e) => e.attrs.account === 'PLT-REV-PSC')?.attrs.metadata || {};
    expect(String(revMeta.businessReference || '')).toContain('Rechnung');
  });

  test('idempotent re-run does not emit a duplicate BankContra or AppLedger set', async () => {
    existingInvoiceRow = { id: 'invoice-existing', batchId: 'batch-42', invoiceType: 'service_charge' };
    const handler = cloudFunctions.bookAppServiceCharge;

    const result = await handler({ user: investorUser, params: { investmentId: 'inv-42' } });

    expect(result.success).toBe(true);
    expect(result.skipped).toBe(true);
    expect(savedInvoices).toHaveLength(0);
    expect(savedBankContraPostings).toHaveLength(0);
    expect(savedAppLedgerEntries).toHaveLength(0);
  });

  test('afterSave Invoice ignores non-service-charge invoice types', async () => {
    // Manually create a non-service_charge invoice and save it; the trigger
    // must be a no-op for these (e.g. a regular trade invoice).
    const Invoice = global.Parse.Object.extend('Invoice');
    const invoice = new Invoice();
    invoice.set('invoiceType', 'trade');
    invoice.set('totalAmount', 1234);
    invoice.set('batchId', 'batch-other');
    await invoice.save();

    expect(savedBankContraPostings).toHaveLength(0);
    expect(savedAppLedgerEntries).toHaveLength(0);
  });

  test('derives VAT split from gross when taxAmount is zero', async () => {
    const Invoice = global.Parse.Object.extend('Invoice');
    const invoice = new Invoice();
    invoice.set('invoiceType', 'service_charge');
    invoice.set('batchId', 'batch-vat-fallback');
    invoice.set('investmentId', 'inv-vat-fallback');
    invoice.set('investmentIds', ['inv-vat-fallback']);
    invoice.set('userId', 'user-1');
    invoice.set('customerId', 'user-1');
    invoice.set('customerName', 'Investor Test');
    invoice.set('totalAmount', 60);
    invoice.set('subtotal', 60);
    invoice.set('taxRate', 19);
    invoice.set('taxAmount', 0);
    await invoice.save();

    expect(savedBankContraPostings).toHaveLength(2);
    const net = savedBankContraPostings.find((p) => p.attrs.account === 'BANK-PS-NET');
    const vat = savedBankContraPostings.find((p) => p.attrs.account === 'BANK-PS-VAT');
    expect(net.attrs.amount).toBeCloseTo(50.42, 2);
    expect(vat.attrs.amount).toBeCloseTo(9.58, 2);
    expect(net.attrs.amount + vat.attrs.amount).toBeCloseTo(60, 2);

    const rev = savedAppLedgerEntries.find((e) => e.attrs.account === 'PLT-REV-PSC');
    const tax = savedAppLedgerEntries.find((e) => e.attrs.account === 'PLT-TAX-VAT');
    const liab = savedAppLedgerEntries.find((e) => e.attrs.account === 'CLT-LIAB-AVA');
    expect(rev.attrs.amount).toBeCloseTo(50.42, 2);
    expect(tax.attrs.amount).toBeCloseTo(9.58, 2);
    expect(liab.attrs.amount).toBeCloseTo(60, 2);
  });

  test('status changes after charge do not mutate postings', async () => {
    const handler = cloudFunctions.bookAppServiceCharge;
    const first = await handler({ user: investorUser, params: { investmentId: 'inv-42' } });
    expect(first.success).toBe(true);
    expect(first.skipped).toBe(false);
    expect(savedInvoices).toHaveLength(1);
    expect(savedBankContraPostings).toHaveLength(2);
    expect(savedAppLedgerEntries).toHaveLength(3);

    investmentRow.attrs.status = 'cancelled';
    existingInvoiceRow = {
      id: savedInvoices[0].id,
      batchId: 'batch-42',
      invoiceType: 'service_charge',
    };
    const second = await handler({ user: investorUser, params: { investmentId: 'inv-42' } });
    expect(second.success).toBe(true);
    expect(second.skipped).toBe(true);
    expect(savedInvoices).toHaveLength(1);
    expect(savedBankContraPostings).toHaveLength(2);
    expect(savedAppLedgerEntries).toHaveLength(3);
  });
});
