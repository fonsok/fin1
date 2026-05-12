'use strict';

// Admin observability: `getMirrorBasisDriftStatus`.
// Reads the latest snapshot written by the weekly drift-check cron job out of
// the `OpsHealthSnapshot` Mongo collection and renders an admin-portal-ready
// summary. This suite covers the three shapes the admin section must handle:
//   1. no snapshot yet (fresh install) → `overall: unknown`
//   2. healthy + fresh snapshot        → `overall: healthy`
//   3. drifted documents               → `overall: degraded`
//   4. very stale snapshot             → `overall: down`

describe('getMirrorBasisDriftStatus (admin observability)', () => {
  const cloudFunctions = {};

  const adminUser = {
    id: 'admin-1',
    get(key) {
      if (key === 'role') return 'admin';
      return null;
    },
  };

  const investorUser = {
    id: 'user-1',
    get(key) {
      if (key === 'role') return 'investor';
      return null;
    },
  };

  let snapshotRow;

  function makeSnapshot(overrides = {}) {
    const runAt = overrides.runAt || new Date();
    const base = {
      driftedDocuments: 0,
      checkedDocuments: 42,
      nullDerivedCount: 0,
      healthy: true,
      commissionRate: 0.11,
      epsilonPp: 0.05,
      driftSamples: [],
      runAt,
      updatedAt: runAt,
    };
    Object.assign(base, overrides);
    return {
      id: 'mirror-basis-drift',
      attrs: base,
      get(key) { return this.attrs[key]; },
    };
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
    }
    async get(id) {
      if (this.className === 'OpsHealthSnapshot' && id === 'mirror-basis-drift') {
        if (snapshotRow) return snapshotRow;
        const err = new global.Parse.Error(101, 'Object not found');
        throw err;
      }
      throw new global.Parse.Error(101, 'Object not found');
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((k) => delete cloudFunctions[k]);
    snapshotRow = null;

    global.Parse = {
      Cloud: {
        define(name, fn) { cloudFunctions[name] = fn; },
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    jest.doMock('../../../utils/permissions', () => ({
      requireAdminRole(request) {
        if (!request.user) {
          throw new global.Parse.Error(209, 'Login required');
        }
        if (request.user.get('role') !== 'admin') {
          throw new global.Parse.Error(119, 'Admin access required');
        }
      },
    }));

    // eslint-disable-next-line global-require
    require('../opsHealth');
  });

  test('returns unknown when no snapshot exists', async () => {
    const handler = cloudFunctions.getMirrorBasisDriftStatus;
    const result = await handler({ user: adminUser, params: {} });
    expect(result.overall).toBe('unknown');
    expect(result.hasSnapshot).toBe(false);
    expect(result.reason).toMatch(/no snapshot yet/);
  });

  test('returns healthy when snapshot is fresh and drifted=0', async () => {
    snapshotRow = makeSnapshot();
    const handler = cloudFunctions.getMirrorBasisDriftStatus;
    const result = await handler({ user: adminUser, params: {} });
    expect(result.overall).toBe('healthy');
    expect(result.hasSnapshot).toBe(true);
    expect(result.driftedDocuments).toBe(0);
    expect(result.checkedDocuments).toBe(42);
    expect(result.ageSeconds).toBeGreaterThanOrEqual(0);
    expect(result.reason).toBeNull();
  });

  test('returns degraded when drifted documents > 0', async () => {
    snapshotRow = makeSnapshot({
      driftedDocuments: 3,
      healthy: false,
      driftSamples: [
        { docId: 'doc-1', storedReturnPercentage: 63.83, derivedReturnPercentage: 64.0, deltaPp: 0.17 },
      ],
    });
    const handler = cloudFunctions.getMirrorBasisDriftStatus;
    const result = await handler({ user: adminUser, params: {} });
    expect(result.overall).toBe('degraded');
    expect(result.driftedDocuments).toBe(3);
    expect(result.reason).toMatch(/drifted/);
    expect(result.driftSamples).toHaveLength(1);
  });

  test('returns down when snapshot is older than 14 days', async () => {
    const ancient = new Date(Date.now() - 20 * 24 * 60 * 60 * 1000);
    snapshotRow = makeSnapshot({ runAt: ancient, updatedAt: ancient });
    const handler = cloudFunctions.getMirrorBasisDriftStatus;
    const result = await handler({ user: adminUser, params: {} });
    expect(result.overall).toBe('down');
    expect(result.reason).toMatch(/stale/);
  });

  test('rejects non-admin users', async () => {
    const handler = cloudFunctions.getMirrorBasisDriftStatus;
    await expect(
      handler({ user: investorUser, params: {} })
    ).rejects.toThrow(/Admin access required/);
  });

  test('accepts master-key calls without a user session (for smokes)', async () => {
    snapshotRow = makeSnapshot();
    const handler = cloudFunctions.getMirrorBasisDriftStatus;
    const result = await handler({ master: true, params: {} });
    expect(result.overall).toBe('healthy');
  });
});

describe('getTradeSettlementConsistencyStatus (admin observability)', () => {
  const cloudFunctions = {};
  const adminUser = {
    id: 'admin-1',
    get(key) { return key === 'role' ? 'admin' : null; },
  };

  const db = {
    trades: [],
    participations: [],
    investments: [],
    accountStatements: [],
    documents: [],
  };

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = [];
      this._limit = null;
    }
    equalTo(field, value) {
      this.filters.push((row) => (field === 'objectId' ? row.id : row[field]) === value);
      return this;
    }
    containedIn(field, values) {
      this.filters.push((row) => values.includes(field === 'objectId' ? row.id : row[field]));
      return this;
    }
    descending() { return this; }
    limit(value) { this._limit = value; return this; }
    async get(id) {
      if (this.className === 'Investment') {
        const row = db.investments.find((r) => r.id === id);
        if (!row) throw new global.Parse.Error(101, 'Object not found');
        return { id: row.id, get: (key) => row[key] };
      }
      throw new global.Parse.Error(101, 'Object not found');
    }
    async find() {
      const source = this.className === 'Trade' ? db.trades
        : this.className === 'PoolTradeParticipation' ? db.participations
          : this.className === 'Investment' ? db.investments
          : this.className === 'AccountStatement' ? db.accountStatements
            : this.className === 'Document' ? db.documents
              : [];
      let rows = [...source];
      for (const f of this.filters) rows = rows.filter(f);
      if (typeof this._limit === 'number') rows = rows.slice(0, this._limit);
      return rows.map((row) => ({
        id: row.id,
        get: (key) => row[key],
      }));
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((k) => delete cloudFunctions[k]);
    db.trades = [
      { id: 'trade-1', status: 'completed', tradeNumber: 11, updatedAt: new Date('2026-05-01T10:00:00Z') },
    ];
    db.participations = [
      { id: 'ptp-1', tradeId: 'trade-1', investmentId: 'inv-1', allocatedAmount: 1000, profitShare: 120, commissionAmount: 12 },
    ];
    db.investments = [
      { id: 'inv-1', investorId: 'investor-1' },
    ];
    db.accountStatements = [
      { id: 's1', userId: 'investor-1', tradeId: 'trade-1', investmentId: 'inv-1', entryType: 'investment_return', amount: 1120, source: 'backend' },
      { id: 's2', userId: 'investor-1', tradeId: 'trade-1', investmentId: 'inv-1', entryType: 'commission_debit', amount: -12, source: 'backend' },
      { id: 's3', userId: 'investor-1', tradeId: 'trade-1', investmentId: 'inv-1', entryType: 'withholding_tax_debit', amount: -3, source: 'backend' },
      { id: 's4', userId: 'investor-1', tradeId: 'trade-1', investmentId: 'inv-1', entryType: 'solidarity_surcharge_debit', amount: -0.2, source: 'backend' },
    ];
    db.documents = [
      { id: 'd1', userId: 'investor-1', tradeId: 'trade-1', investmentId: 'inv-1', type: 'investorCollectionBill', source: 'backend', metadata: { taxBreakdown: { totalTax: 3.2 } } },
    ];

    global.Parse = {
      Cloud: { define(name, fn) { cloudFunctions[name] = fn; } },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) { super(message); this.code = code; }
      },
    };
    global.Parse.Error.OBJECT_NOT_FOUND = 101;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;

    jest.doMock('../../../utils/permissions', () => ({
      requireAdminRole(request) {
        if (!request.user) throw new global.Parse.Error(209, 'Login required');
        if (request.user.get('role') !== 'admin') throw new global.Parse.Error(119, 'Admin access required');
      },
    }));

    // eslint-disable-next-line global-require
    require('../opsHealth');
  });

  test('returns healthy when expected and actual sums match', async () => {
    const handler = cloudFunctions.getTradeSettlementConsistencyStatus;
    const result = await handler({ user: adminUser, params: { limit: 10 } });
    expect(result.overall).toBe('healthy');
    expect(result.checkedTrades).toBe(1);
    expect(result.checkedInvestments).toBe(1);
    expect(result.mismatchCount).toBe(0);
  });

  test('returns degraded when settlement sums drift', async () => {
    db.accountStatements = db.accountStatements.filter((r) => r.entryType !== 'commission_debit');
    const handler = cloudFunctions.getTradeSettlementConsistencyStatus;
    const result = await handler({ user: adminUser, params: { limit: 10 } });
    expect(result.overall).toBe('degraded');
    expect(result.mismatchCount).toBe(1);
    expect(result.mismatchSamples[0].diff.commission).not.toBe(0);
  });
});

describe('runFinanceConsistencySmoke (admin observability)', () => {
  const cloudFunctions = {};
  const adminUser = { get: (key) => (key === 'role' ? 'admin' : null) };
  const appLedgerRows = [
    {
      id: 'ale-1',
      createdAt: new Date(),
      userId: 'u123',
      metadata: { userUsername: 'eweber', userDisplayName: 'E Weber' },
    },
  ];
  const accountStatements = [
    {
      id: 'stmt-1',
      createdAt: new Date(),
      source: 'backend',
      entryType: 'trade_sell',
      userId: 'u123',
      tradeId: 't1',
      investmentId: 'inv1',
      referenceDocumentId: 'doc-1',
      referenceDocumentNumber: 'TSC-2026-0000001',
    },
  ];

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = [];
      this._limit = null;
    }
    equalTo(field, value) { this.filters.push((r) => (field === 'objectId' ? r.id : r[field]) === value); return this; }
    containedIn(field, values) { this.filters.push((r) => values.includes(field === 'objectId' ? r.id : r[field])); return this; }
    greaterThanOrEqualTo(field, value) { this.filters.push((r) => r[field] >= value); return this; }
    descending() { return this; }
    limit(v) { this._limit = v; return this; }
    async find() {
      const source = this.className === 'AppLedgerEntry' ? appLedgerRows
        : this.className === 'AccountStatement' ? accountStatements
          : [];
      let rows = [...source];
      for (const f of this.filters) rows = rows.filter(f);
      if (typeof this._limit === 'number') rows = rows.slice(0, this._limit);
      return rows.map((row) => ({ id: row.id, get: (key) => row[key] }));
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((k) => delete cloudFunctions[k]);
    global.Parse = {
      Cloud: {
        define(name, fn) { cloudFunctions[name] = fn; },
        async run(name) {
          if (name === 'getMirrorBasisDriftStatus') return { overall: 'unknown', hasSnapshot: false };
          if (name === 'getTradeSettlementConsistencyStatus') return { overall: 'healthy', mismatchCount: 0 };
          throw new Error(`unexpected cloud run: ${name}`);
        },
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) { super(message); this.code = code; }
      },
    };
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    jest.doMock('../../../utils/permissions', () => ({
      requireAdminRole(request) {
        if (!request.user) throw new global.Parse.Error(209, 'Login required');
        if (request.user.get('role') !== 'admin') throw new global.Parse.Error(119, 'Admin access required');
      },
    }));

    // eslint-disable-next-line global-require
    require('../opsHealth');
  });

  test('returns healthy when smoke checks have no issues', async () => {
    const handler = cloudFunctions.runFinanceConsistencySmoke;
    const result = await handler({ user: adminUser, params: { userFilter: 'eweber' } });
    expect(result.overall).toBe('healthy');
    expect(result.issues).toHaveLength(0);
    expect(result.ledgerFuzzySmoke.matches).toBeGreaterThan(0);
    expect(result.referenceCoverage.missingReferenceDocumentId).toBe(0);
  });
});

describe('benchmarkTradeSettlementConsistencySynthetic (admin observability)', () => {
  const cloudFunctions = {};
  const adminUser = { get: (key) => (key === 'role' ? 'admin' : null) };

  class FakeQuery {
    constructor() {}
    equalTo() { return this; }
    containedIn() { return this; }
    descending() { return this; }
    limit() { return this; }
    greaterThanOrEqualTo() { return this; }
    async find() { return []; }
    async get() { throw new Error('not implemented'); }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((k) => delete cloudFunctions[k]);
    global.Parse = {
      Cloud: {
        define(name, fn) { cloudFunctions[name] = fn; },
        async run() { return { overall: 'healthy' }; },
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) { super(message); this.code = code; }
      },
    };
    global.Parse.Error.INVALID_SESSION_TOKEN = 209;
    global.Parse.Error.OPERATION_FORBIDDEN = 119;

    jest.doMock('../../../utils/permissions', () => ({
      requireAdminRole(request) {
        if (!request.user) throw new global.Parse.Error(209, 'Login required');
        if (request.user.get('role') !== 'admin') throw new global.Parse.Error(119, 'Admin access required');
      },
    }));

    // eslint-disable-next-line global-require
    require('../opsHealth');
  });

  test('returns scenario-based benchmark results', async () => {
    const handler = cloudFunctions.benchmarkTradeSettlementConsistencySynthetic;
    const result = await handler({
      user: adminUser,
      params: { scenarios: [{ trades: 2, participationsPerTrade: 10 }] },
    });
    expect(result.benchmarkType).toBe('synthetic');
    expect(result.results).toHaveLength(1);
    expect(result.results[0].totalParticipations).toBe(20);
    expect(result.results[0].estimatedReduction).toBeGreaterThan(0);
    expect(result.results[0].runtime.checkedInvestments).toBe(20);
  });
});
