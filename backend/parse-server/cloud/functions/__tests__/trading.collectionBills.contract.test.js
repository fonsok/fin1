'use strict';

describe('trading collection bill return% contract', () => {
  const cloudFunctions = {};

  const documents = [
    {
      id: 'doc-modern',
      userId: 'investor:1',
      type: 'investor_collection_bill',
      investmentId: 'inv-1',
      tradeId: 'trade-1',
      metadata: { returnPercentage: 12.34 },
      createdAt: new Date('2026-04-20T10:00:00Z'),
      toJSON() { return { ...this }; },
      get(field) { return this[field]; },
    },
    {
      id: 'doc-legacy',
      userId: 'investor:1',
      type: 'investorCollectionBill',
      investmentId: 'inv-1',
      tradeId: 'trade-2',
      metadata: { returnPercentage: 9.87 },
      createdAt: new Date('2026-04-20T09:00:00Z'),
      toJSON() { return { ...this }; },
      get(field) { return this[field]; },
    },
    {
      id: 'doc-other-user',
      userId: 'investor:2',
      type: 'investor_collection_bill',
      investmentId: 'inv-2',
      tradeId: 'trade-3',
      metadata: { returnPercentage: 1.11 },
      createdAt: new Date('2026-04-20T08:00:00Z'),
      toJSON() { return { ...this }; },
      get(field) { return this[field]; },
    },
    {
      // Activation / wallet receipt — same `type` as real bills but marked
      // via `metadata.receiptType`. Must be filtered out by the listing
      // endpoint so that the client never receives docs without
      // `returnPercentage` (which would trigger the "pending" bug).
      id: 'doc-activation-receipt',
      userId: 'investor:1',
      type: 'investorCollectionBill',
      investmentId: 'inv-1',
      tradeId: undefined,
      metadata: {
        receiptType: 'investment',
        amount: 1000,
        description: 'Investment activation receipt',
      },
      createdAt: new Date('2026-04-20T07:00:00Z'),
      toJSON() { return { ...this }; },
      get(field) { return this[field]; },
    },
  ];

  function getPath(obj, dotted) {
    return dotted.split('.').reduce((acc, key) => (acc == null ? undefined : acc[key]), obj);
  }

  class FakeQuery {
    constructor() {
      this.filters = [];
      this._limit = null;
      this._skip = 0;
      this._descendingField = null;
    }

    equalTo(field, value) {
      this.filters.push((doc) => getPath(doc, field) === value);
      return this;
    }

    containedIn(field, values) {
      this.filters.push((doc) => values.includes(getPath(doc, field)));
      return this;
    }

    doesNotExist(field) {
      this.filters.push((doc) => getPath(doc, field) === undefined);
      return this;
    }

    descending(field) {
      this._descendingField = field;
      return this;
    }

    limit(value) {
      this._limit = value;
      return this;
    }

    skip(value) {
      this._skip = value;
      return this;
    }

    _apply() {
      let result = [...documents];
      for (const filter of this.filters) {
        result = result.filter(filter);
      }
      if (this._descendingField === 'createdAt') {
        result.sort((a, b) => b.createdAt - a.createdAt);
      }
      if (this._skip) {
        result = result.slice(this._skip);
      }
      if (this._limit != null) {
        result = result.slice(0, this._limit);
      }
      return result;
    }

    async find() {
      return this._apply();
    }

    async count() {
      return this._apply().length;
    }
  }

  class FakeOrQuery {
    constructor(queries) {
      this.queries = queries;
      this._limit = null;
      this._descendingField = null;
    }

    descending(field) {
      this._descendingField = field;
      return this;
    }

    limit(value) {
      this._limit = value;
      return this;
    }

    _apply() {
      const byId = new Map();
      for (const query of this.queries) {
        for (const doc of query._apply()) {
          byId.set(doc.id, doc);
        }
      }
      let result = [...byId.values()];
      if (this._descendingField === 'createdAt') {
        result.sort((a, b) => b.createdAt - a.createdAt);
      }
      if (this._limit != null) {
        result = result.slice(0, this._limit);
      }
      return result;
    }

    async find() {
      return this._apply();
    }

    async count() {
      return this._apply().length;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    Object.keys(cloudFunctions).forEach((key) => delete cloudFunctions[key]);

    global.Parse = {
      Cloud: {
        define(name, fn) {
          cloudFunctions[name] = fn;
        },
      },
      Query: FakeQuery,
      Error: class ParseError extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
    };
    global.Parse.Query.or = (...queries) => new FakeOrQuery(queries);

    // eslint-disable-next-line global-require
    require('../trading');
  });

  test('getInvestorCollectionBills includes both modern and legacy document types', async () => {
    const handler = cloudFunctions.getInvestorCollectionBills;
    const request = {
      user: {
        get(key) {
          if (key === 'stableId') return 'investor:1';
          return null;
        },
      },
      params: { investmentId: 'inv-1' },
    };

    const result = await handler(request);

    expect(result.collectionBills).toHaveLength(2);
    expect(result.collectionBills.map((d) => d.type).sort()).toEqual([
      'investorCollectionBill',
      'investor_collection_bill',
    ]);
    expect(result.collectionBills.map((d) => d.metadata.returnPercentage).sort((a, b) => a - b)).toEqual([9.87, 12.34]);
  });

  test('getInvestorCollectionBills excludes activation receipts (metadata.receiptType)', async () => {
    const handler = cloudFunctions.getInvestorCollectionBills;
    const request = {
      user: {
        get(key) {
          if (key === 'stableId') return 'investor:1';
          return null;
        },
      },
      params: { investmentId: 'inv-1' },
    };

    const result = await handler(request);

    // Must NOT contain the activation receipt even though it shares the
    // investorCollectionBill `type`. Otherwise the iOS resolver would see a
    // document without `returnPercentage` and display "pending" to the user.
    const ids = result.collectionBills.map((d) => d.id);
    expect(ids).not.toContain('doc-activation-receipt');
    result.collectionBills.forEach((bill) => {
      expect(bill.metadata && bill.metadata.receiptType).toBeUndefined();
      expect(bill.metadata.returnPercentage).toEqual(expect.any(Number));
    });
  });

  test('auditCollectionBillReturnPercentage supports master-key automation path', async () => {
    const handler = cloudFunctions.auditCollectionBillReturnPercentage;

    const result = await handler({
      master: true,
      params: { limit: 10 },
    });

    // Only real settlement bills (receiptType absent); the activation receipt
    // is excluded by the same `metadata.receiptType` filter the audit uses.
    expect(result.totalActiveCollectionBills).toBe(3);
    expect(result.missingReturnPercentageCount).toBe(0);
    expect(result.healthy).toBe(true);
  });
});
