'use strict';

describe('userDocumentInbox', () => {
  const cloudFunctions = {};
  let isDisplayableInUserInbox;

  const documents = [
    {
      id: 'cb-1',
      userId: 'inv-1',
      type: 'investorCollectionBill',
      name: 'CollectionBill_x',
      get(field) { return this[field]; },
      toJSON() { return { ...this, objectId: this.id }; },
    },
    {
      id: 'cn-1',
      userId: 'trd-1',
      type: 'traderCreditNote',
      name: 'CreditNote_x',
      get(field) { return this[field]; },
      toJSON() { return { ...this, objectId: this.id }; },
    },
    {
      id: 'eigen-1',
      userId: 'inv-1',
      type: 'investmentReservationEigenbeleg',
      name: 'Eigenbeleg',
      get(field) { return this[field]; },
      toJSON() { return { ...this, objectId: this.id }; },
    },
    {
      id: 'iar-1',
      userId: 'inv-1',
      type: 'financial',
      accountingDocumentNumber: 'IAR-2026-0001',
      name: 'wallet',
      get(field) { return this[field]; },
      toJSON() { return { ...this, objectId: this.id }; },
    },
    {
      id: 'act-1',
      userId: 'inv-1',
      type: 'investorCollectionBill',
      metadata: { receiptType: 'investment' },
      name: 'activation',
      get(field) { return this[field]; },
      toJSON() { return { ...this, objectId: this.id }; },
    },
    {
      id: 'cb-by-inv',
      userId: 'legacy-wrong-key',
      investmentId: 'inv-1',
      type: 'investorCollectionBill',
      name: 'CollectionBill_legacy',
      get(field) { return this[field]; },
      toJSON() { return { ...this, objectId: this.id }; },
    },
  ];

  const investments = [
    { id: 'inv-1', investorId: 'inv-1' },
  ];

  test('isDisplayableInUserInbox excludes eigenbeleg, IAR, activation receipts', () => {
    expect(isDisplayableInUserInbox(documents[0])).toBe(true);
    expect(isDisplayableInUserInbox(documents[1])).toBe(true);
    expect(isDisplayableInUserInbox(documents[2])).toBe(false);
    expect(isDisplayableInUserInbox(documents[3])).toBe(false);
    expect(isDisplayableInUserInbox(documents[4])).toBe(false);
  });

  test('isDisplayableInUserInbox excludes internal pool-mirror and fees belege', () => {
    const { isInternalInboxDocument } = require('../userDocumentInbox');
    const poolMirror = {
      get(field) {
        return ({
          type: 'poolMirrorExecutionEigenbeleg',
          accountingDocumentNumber: 'PMBC-2026-0000001',
          name: 'Pool-Mirror Eigenbeleg',
        })[field];
      },
    };
    const feesDoc = {
      get(field) {
        return ({
          type: 'invoice',
          accountingDocumentNumber: 'TFS-2026-0000001',
          metadata: { executionType: 'fees' },
          name: 'Gebührenabrechnung',
        })[field];
      },
    };
    const tbc = {
      get(field) {
        return ({
          type: 'traderCollectionBill',
          accountingDocumentNumber: 'TBC-2026-0000002',
          name: 'Kaufabrechnung',
        })[field];
      },
    };
    expect(isInternalInboxDocument(poolMirror)).toBe(true);
    expect(isInternalInboxDocument(feesDoc)).toBe(true);
    expect(isDisplayableInUserInbox(poolMirror)).toBe(false);
    expect(isDisplayableInUserInbox(feesDoc)).toBe(false);
    expect(isDisplayableInUserInbox(tbc)).toBe(true);
  });

  beforeAll(() => {
    jest.resetModules();
    global.Parse = {
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_SESSION_TOKEN() { return 209; }
        static get INVALID_VALUE() { return 102; }
      },
      Query: class MockQuery {
        constructor(className) {
          this.className = className || 'Document';
          this.filters = [];
          this._orQueries = null;
          this._limit = 100;
          this._skip = 0;
        }
        static or(...queries) {
          const combined = new MockQuery('Document');
          combined._orQueries = queries;
          return combined;
        }
        containedIn(field, values) {
          this.filters.push((row) => values.includes(row[field]));
          return this;
        }
        doesNotExist(field) {
          this.filters.push((row) => {
            const value = field.split('.').reduce((acc, key) => (acc == null ? undefined : acc[key]), row);
            return value === undefined || value === null;
          });
          return this;
        }
        descending() { return this; }
        limit(n) { this._limit = n; return this; }
        skip(n) { this._skip = n; return this; }
        async find() {
          const source = this.className === 'Investment' ? investments : documents;
          let rows;
          if (this._orQueries) {
            const seen = new Set();
            rows = [];
            for (const sub of this._orQueries) {
              const part = source.filter((row) => sub.filters.every((f) => f(row)));
              for (const row of part) {
                if (!seen.has(row.id)) {
                  seen.add(row.id);
                  rows.push(row);
                }
              }
            }
          } else {
            rows = source.filter((row) => this.filters.every((f) => f(row)));
          }
          return rows.slice(this._skip, this._skip + this._limit).map((row) => ({
            id: row.id,
            get(k) { return row[k]; },
            toJSON() { return { ...row, objectId: row.id }; },
          }));
        }
      },
      Object: { extend: (name) => class extends Parse.Query { constructor() { super(name); } } },
      Cloud: { define: (name, fn) => { cloudFunctions[name] = fn; } },
    };
    jest.doMock('../../utils/canonicalUserId', () => ({
      collectLedgerUserIdCandidates: (user) => [user.id],
    }));
    require('../trading');
    ({ isDisplayableInUserInbox } = require('../userDocumentInbox'));
  });

  test('buildInvestorCollectionBillQuery merges userId and investmentId rows', async () => {
    const { buildInvestorCollectionBillQuery } = require('../userDocumentInbox');
    const q = await buildInvestorCollectionBillQuery(['inv-1']);
    const rows = await q.find();
    const ids = rows.map((r) => r.id);
    expect(ids).toContain('cb-by-inv');
    expect(ids).not.toContain('act-1');
  });

  test('buildUserInboxDocumentQuery merges userId and investmentId rows', async () => {
    const { buildUserInboxDocumentQuery } = require('../userDocumentInbox');
    const q = await buildUserInboxDocumentQuery(['inv-1']);
    const rows = await q.find();
    const ids = rows.map((r) => r.id);
    expect(ids).toContain('cb-by-inv');
  });

  test('getUserDocumentInbox returns displayable docs for session user', async () => {
    const handler = cloudFunctions.getUserDocumentInbox;
    const result = await handler({
      user: { id: 'inv-1', get: () => null },
      params: { limit: 50 },
    });
    const ids = result.documents.map((d) => d.objectId || d.id);
    expect(ids).toContain('cb-1');
    expect(ids).toContain('cb-by-inv');
    expect(ids).not.toContain('eigen-1');
    expect(ids).not.toContain('iar-1');
    expect(ids).not.toContain('act-1');
  });
});
