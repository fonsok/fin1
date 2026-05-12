'use strict';

describe('reconcileAccountStatementDocumentReferences (admin financial)', () => {
  const cloudFunctions = {};

  const adminUser = {
    id: 'admin-1',
    get(key) {
      if (key === 'role') return 'admin';
      return null;
    },
  };

  const db = {
    statements: [],
    documents: [],
  };

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = [];
      this._limit = null;
    }

    equalTo(field, value) {
      this.filters.push((row) => row[field] === value);
      return this;
    }

    containedIn(field, values) {
      this.filters.push((row) => values.includes(field === 'objectId' ? row.id : row[field]));
      return this;
    }

    descending() { return this; }
    limit(value) { this._limit = value; return this; }

    async find() {
      const source = this.className === 'AccountStatement' ? db.statements
        : this.className === 'Document' ? db.documents
          : [];
      let rows = [...source];
      for (const f of this.filters) rows = rows.filter(f);
      if (typeof this._limit === 'number') rows = rows.slice(0, this._limit);
      return rows.map((row) => ({
        id: row.id,
        set: (key, value) => { row[key] = value; },
        get: (key) => row[key],
      }));
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((k) => delete cloudFunctions[k]);

    db.statements = [
      // missing number, id present
      { id: 'stmt-1', source: 'backend', userId: 'u1', tradeId: 't1', investmentId: 'i1', referenceDocumentId: 'doc-1', referenceDocumentNumber: '' },
      // missing id, number present (unique by number)
      { id: 'stmt-2', source: 'backend', userId: 'u2', tradeId: 't2', investmentId: 'i2', referenceDocumentId: '', referenceDocumentNumber: 'CB-2026-0002' },
      // healthy
      { id: 'stmt-3', source: 'backend', userId: 'u3', tradeId: 't3', investmentId: 'i3', referenceDocumentId: 'doc-3', referenceDocumentNumber: 'CN-2026-0003' },
      // ambiguous by number (same number on two docs with same scope score)
      { id: 'stmt-4', source: 'backend', userId: 'uX', tradeId: '', investmentId: '', referenceDocumentId: '', referenceDocumentNumber: 'DUP-0001' },
      // missing both
      { id: 'stmt-5', source: 'backend', userId: 'u5', tradeId: 't5', investmentId: 'i5', referenceDocumentId: '', referenceDocumentNumber: '' },
    ];

    db.documents = [
      { id: 'doc-1', accountingDocumentNumber: 'CB-2026-0001', userId: 'u1', tradeId: 't1', investmentId: 'i1' },
      { id: 'doc-2', accountingDocumentNumber: 'CB-2026-0002', userId: 'u2', tradeId: 't2', investmentId: 'i2' },
      { id: 'doc-3', accountingDocumentNumber: 'CN-2026-0003', userId: 'u3', tradeId: 't3', investmentId: 'i3' },
      { id: 'doc-4', accountingDocumentNumber: 'DUP-0001', userId: 'a1', tradeId: '', investmentId: '' },
      { id: 'doc-5', accountingDocumentNumber: 'DUP-0001', userId: 'a2', tradeId: '', investmentId: '' },
    ];

    global.Parse = {
      Cloud: {
        define(name, fn) { cloudFunctions[name] = fn; },
      },
      Query: FakeQuery,
      Object: {
        async saveAll(rows) {
          return rows;
        },
      },
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    jest.doMock('../../../utils/permissions', () => ({
      requirePermission: () => {},
      logPermissionCheck: async () => {},
      requireAdminRole(request) {
        if (!request.user) throw new global.Parse.Error(209, 'Login required');
        if (request.user.get('role') !== 'admin') throw new global.Parse.Error(119, 'Admin access required');
      },
    }));
    jest.doMock('../../../utils/configHelper/index.js', () => ({
      getTraderCommissionRate: async () => 0.1,
    }));
    jest.doMock('../../../utils/accountingHelper/repair', () => ({
      repairTradeSettlement: async () => ({ success: true }),
    }));
    jest.doMock('../../../utils/accountingHelper', () => ({
      settleAndDistribute: async () => ({ success: true }),
    }));
    jest.doMock('../../../utils/accountingHelper/retryQueue', () => ({
      processDueSettlementRetries: async () => ({ processed: 0, results: [] }),
      getSettlementRetryQueueStatus: async () => ({ pending: 0 }),
    }));

    // eslint-disable-next-line global-require
    require('../financial');
  });

  test('dryRun reports candidates and unresolved without mutating rows', async () => {
    const handler = cloudFunctions.reconcileAccountStatementDocumentReferences;
    const result = await handler({ user: adminUser, params: { dryRun: true } });

    expect(result.success).toBe(true);
    expect(result.dryRun).toBe(true);
    expect(result.backfillCandidates).toBe(2);
    expect(result.backfilled).toBe(0);
    expect(result.unresolvedCount).toBe(2);

    const stmt1 = db.statements.find((s) => s.id === 'stmt-1');
    const stmt2 = db.statements.find((s) => s.id === 'stmt-2');
    expect(stmt1.referenceDocumentNumber).toBe('');
    expect(stmt2.referenceDocumentId).toBe('');
  });

  test('execute backfills unambiguous rows only', async () => {
    const handler = cloudFunctions.reconcileAccountStatementDocumentReferences;
    const result = await handler({ user: adminUser, params: { dryRun: false } });

    expect(result.backfillCandidates).toBe(2);
    expect(result.backfilled).toBe(2);

    const stmt1 = db.statements.find((s) => s.id === 'stmt-1');
    const stmt2 = db.statements.find((s) => s.id === 'stmt-2');
    const stmt4 = db.statements.find((s) => s.id === 'stmt-4');

    expect(stmt1.referenceDocumentNumber).toBe('CB-2026-0001');
    expect(stmt2.referenceDocumentId).toBe('doc-2');
    // ambiguous number stays untouched
    expect(stmt4.referenceDocumentId).toBe('');
  });
});
