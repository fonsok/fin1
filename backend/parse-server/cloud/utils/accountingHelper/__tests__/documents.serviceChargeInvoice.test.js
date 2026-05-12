'use strict';

describe('ensureServiceChargeInvoiceDocument', () => {
  const { ensureServiceChargeInvoiceDocument } = require('../documents');

  let savedDocs;
  let findFirstResult;

  function makeInvoice(overrides = {}) {
    const attrs = Object.assign({
      invoiceType: 'service_charge',
      invoiceNumber: 'SC-2026-0000001',
      userId: 'user-a',
      customerId: 'user-a',
      batchId: 'batch-1',
      investmentId: 'inv-1',
      subtotal: 100,
      taxAmount: 19,
      totalAmount: 119,
      businessCaseId: 'bc-1',
      createdAt: new Date('2026-01-15T12:00:00Z'),
    }, overrides);
    return {
      id: 'invObj-1',
      get(k) { return attrs[k]; },
    };
  }

  class FakeDocument {
    constructor() {
      this.attrs = {};
      this.id = undefined;
    }
    set(k, v) { this.attrs[k] = v; }
    get(k) { return this.attrs[k]; }
    async save() {
      if (!this.id) this.id = `doc-${savedDocs.length + 1}`;
      savedDocs.push(this);
      return this;
    }
  }

  beforeEach(() => {
    savedDocs = [];
    findFirstResult = undefined;
    global.Parse = {
      Object: {
        extend(name) {
          if (name === 'Document') return FakeDocument;
          return class X {};
        },
      },
    };
    global.Parse.Query = class {
      static or() {
        return {
          limit() {
            return this;
          },
          async find() {
            return findFirstResult ? [findFirstResult] : [];
          },
        };
      }

      equalTo() { return this; }
      descending() { return this; }
      limit() { return this; }
      async first() {
        return findFirstResult;
      }
      async find() {
        return [];
      }
    };
  });

  it('returns null for non-service invoice types', async () => {
    const inv = makeInvoice({ invoiceType: 'order' });
    const doc = await ensureServiceChargeInvoiceDocument(inv);
    expect(doc).toBeNull();
  });

  it('creates a Document with accountingDocumentNumber equal to invoice number', async () => {
    findFirstResult = undefined;
    const inv = makeInvoice();
    const doc = await ensureServiceChargeInvoiceDocument(inv);
    expect(doc).toBeTruthy();
    expect(doc.get('accountingDocumentNumber')).toBe('SC-2026-0000001');
    expect(doc.get('metadata').sourceInvoiceId).toBe('invObj-1');
    expect(doc.get('type')).toBe('invoice');
  });

  it('returns existing document from first()', async () => {
    const existing = new FakeDocument();
    existing.id = 'existing-1';
    existing.set('accountingDocumentNumber', 'SC-2026-0000001');
    existing.set('metadata', { sourceInvoiceId: 'invObj-1' });
    findFirstResult = existing;
    const inv = makeInvoice();
    const doc = await ensureServiceChargeInvoiceDocument(inv);
    expect(doc.id).toBe('existing-1');
    expect(savedDocs.length).toBe(0);
  });

  it('accepts app_service_charge invoice type', async () => {
    findFirstResult = undefined;
    const inv = makeInvoice({ invoiceType: 'app_service_charge' });
    const doc = await ensureServiceChargeInvoiceDocument(inv);
    expect(doc.get('metadata').invoiceType).toBe('app_service_charge');
  });
});

describe('resolveDocumentRefForFeeRefund', () => {
  const { resolveDocumentRefForFeeRefund } = require('../documents');

  it('returns empty object when userId missing', async () => {
    const r = await resolveDocumentRefForFeeRefund('', 119);
    expect(r).toEqual({});
  });

  it('matches CLT-LIAB-AVA debit by grossAmount', async () => {
    const matchingRow = {
      get(key) {
        if (key === 'amount') return 119;
        if (key === 'metadata') {
          return {
            grossAmount: '119',
            referenceDocumentId: 'doc-99',
            referenceDocumentNumber: 'SC-2026-0000001',
            invoiceId: 'inv-parse-1',
          };
        }
        return null;
      },
    };

    global.Parse = {
      Object: {
        extend() {
          return class {};
        },
      },
    };

    global.Parse.Query = class {
      equalTo() { return this; }
      descending() { return this; }
      limit() { return this; }
      async find() {
        return [matchingRow];
      }
    };

    const r = await resolveDocumentRefForFeeRefund('user-a', 119);
    expect(r.referenceDocumentId).toBe('doc-99');
    expect(r.referenceDocumentNumber).toBe('SC-2026-0000001');
  });

  it('with batchId returns empty when no scoped ledger row (no broad gross fallback)', async () => {
    global.Parse = {
      Object: { extend() { return class {}; } },
    };
    global.Parse.Query = class {
      equalTo() { return this; }
      descending() { return this; }
      limit() { return this; }
      async find() {
        return [];
      }
    };
    const r = await resolveDocumentRefForFeeRefund('user-a', 119, { batchId: 'batch-x' });
    expect(r).toEqual({});
  });

  it('prefers explicit invoiceId when totals match refund gross', async () => {
    class FakeDocument {
      constructor() {
        this.attrs = {};
        this.id = 'doc-by-invoice';
      }
      set(k, v) { this.attrs[k] = v; }
      get(k) { return this.attrs[k]; }
      async save() { return this; }
    }

    const existing = new FakeDocument();
    existing.set('metadata', { sourceInvoiceId: 'parse-inv-42' });

    const invoice = {
      id: 'parse-inv-42',
      get(k) {
        const a = {
          invoiceType: 'service_charge',
          userId: 'user-a',
          customerId: 'user-a',
          invoiceNumber: 'SC-9',
          subtotal: 100,
          taxAmount: 19,
          totalAmount: 119,
        };
        return a[k];
      },
    };

    global.Parse = {
      Object: {
        extend(n) {
          if (n === 'Document') return FakeDocument;
          return class {};
        },
      },
    };
    global.Parse.Query = class {
      static or() {
        return {
          limit() {
            return this;
          },
          async find() {
            return [existing];
          },
        };
      }

      equalTo() { return this; }
      descending() { return this; }
      limit() { return this; }
      async first() {
        return existing;
      }
      async get(id) {
        if (id === 'parse-inv-42') return invoice;
        throw new Error(`unexpected ${id}`);
      }
      async find() {
        return [];
      }
    };

    const r = await resolveDocumentRefForFeeRefund('user-a', 119, { invoiceId: 'parse-inv-42' });
    expect(r.referenceDocumentId).toBe('doc-by-invoice');
    expect(r.referenceDocumentNumber).toBe('SC-9');
  });
});
