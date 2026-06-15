'use strict';

jest.mock('../../configHelper/index.js', () => ({
  loadConfig: jest.fn(async () => ({
    display: { settlementGLOutboxEnabled: true },
  })),
}));

jest.mock('../../structuredLogger', () => ({
  audit: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

const mockPostSettlementGLPair = jest.fn(async () => [{ id: 'ale-1' }]);
jest.mock('../settlementGLPoster', () => ({
  postSettlementGLPair: (...args) => mockPostSettlementGLPair(...args),
}));

describe('settlementOutbox (ADR-017)', () => {
  let savedRows;
  let saveAllOptions;

  class FakeSettlementOutbox {
    constructor() {
      this.attrs = {};
      this.id = undefined;
    }
    set(k, v) { this.attrs[k] = v; }
    get(k) { return this.attrs[k]; }
    unset(k) { delete this.attrs[k]; }
    async save() {
      if (!this.id) {
        this.id = `outbox-${savedRows.length + 1}`;
      }
      const idx = savedRows.findIndex((r) => r.id === this.id);
      if (idx >= 0) savedRows[idx] = this;
      else savedRows.push(this);
      return this;
    }
  }

  class FakeAccountStatement {
    constructor() {
      this.attrs = {};
      this.id = undefined;
    }
    set(k, v) { this.attrs[k] = v; }
    get(k) { return this.attrs[k]; }
    async save() {
      if (!this.id) this.id = `stmt-${savedRows.length + 1}`;
      return this;
    }
  }

  class FakeQuery {
    constructor(className) {
      this.className = className;
      this.filters = {};
      this.containedInFilters = {};
      this.limitValue = 100;
    }
    equalTo(field, value) {
      this.filters[field] = value;
      return this;
    }
    containedIn(field, values) {
      this.containedInFilters[field] = values;
      return this;
    }
    lessThanOrEqualTo() { return this; }
    ascending() { return this; }
    descending() { return this; }
    limit(n) { this.limitValue = n; return this; }
    async first() {
      const rows = savedRows.filter((row) => this.matches(row));
      return rows[0] || undefined;
    }
    async get(id) {
      const row = savedRows.find((r) => r.id === id);
      if (!row) throw new Error(`not found ${id}`);
      return row;
    }
    async find() {
      return savedRows.filter((row) => this.matches(row)).slice(0, this.limitValue);
    }
    async count() {
      return savedRows.filter((row) => this.matches(row)).length;
    }
    matches(row) {
      for (const [field, value] of Object.entries(this.filters)) {
        if (row.get(field) !== value) return false;
      }
      for (const [field, values] of Object.entries(this.containedInFilters)) {
        if (!values.includes(row.get(field))) return false;
      }
      return true;
    }
  }

  beforeEach(() => {
    jest.resetModules();
    savedRows = [];
    saveAllOptions = null;
    mockPostSettlementGLPair.mockClear();

    global.Parse = {
      Object: {
        extend(className) {
          if (className === 'SettlementOutbox') return FakeSettlementOutbox;
          if (className === 'AccountStatement') return FakeAccountStatement;
          throw new Error(`Unexpected class ${className}`);
        },
        async saveAll(rows, options) {
          saveAllOptions = options;
          for (const row of rows) {
            // eslint-disable-next-line no-await-in-loop
            await row.save();
          }
          return rows;
        },
      },
      Query: FakeQuery,
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get INVALID_VALUE() { return 400; }
      },
    };
  });

  test('buildSettlementGLOutboxIdempotencyKey is stable per business grain', () => {
    const { buildSettlementGLOutboxIdempotencyKey } = require('../settlementOutbox');
    const key = buildSettlementGLOutboxIdempotencyKey({
      userId: 'u1',
      tradeId: 't1',
      entryType: 'commission_debit',
      investmentId: 'inv-1',
    });
    expect(key).toBe('gl_outbox:u1:t1:commission_debit:inv-1');
  });

  test('saveAccountStatementWithOutbox uses Mongo transaction', async () => {
    const { saveAccountStatementWithOutbox } = require('../settlementOutbox');
    const entry = new FakeAccountStatement();
    entry.set('entryType', 'commission_debit');

    const payload = {
      userId: 'u1',
      tradeId: 't1',
      entryType: 'commission_debit',
      investmentId: 'inv-1',
      amount: -10,
    };

    const result = await saveAccountStatementWithOutbox(entry, payload);
    expect(saveAllOptions).toEqual({ useMasterKey: true, transaction: true });
    expect(result.entry.id).toBeTruthy();
    expect(result.outbox.get('accountStatementId')).toBe(result.entry.id);
    expect(result.outbox.get('status')).toBe('pending');
  });

  test('postSettlementGLFromOutbox delegates to postSettlementGLPair', async () => {
    const { postSettlementGLFromOutbox } = require('../settlementOutbox');
    const row = new FakeSettlementOutbox();
    row.id = 'outbox-1';
    row.set('payload', {
      userId: 'u1',
      userRole: 'investor',
      entryType: 'commission_debit',
      amount: -5,
      tradeId: 't9',
      accountStatementId: 'stmt-9',
    });
    row.set('accountStatementId', 'stmt-9');

    const ledger = await postSettlementGLFromOutbox(row);
    expect(mockPostSettlementGLPair).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'u1',
        entryType: 'commission_debit',
        accountStatementId: 'stmt-9',
      }),
    );
    expect(ledger).toHaveLength(1);
  });

  test('processDueSettlementOutbox marks row posted', async () => {
    const { processDueSettlementOutbox } = require('../settlementOutbox');
    const row = new FakeSettlementOutbox();
    row.id = 'outbox-due';
    row.set('kind', 'settlement_gl');
    row.set('status', 'pending');
    row.set('nextRetryAt', new Date(Date.now() - 1000));
    row.set('payload', {
      userId: 'u1',
      userRole: 'investor',
      entryType: 'commission_debit',
      amount: -5,
      tradeId: 't9',
    });
    savedRows.push(row);

    const result = await processDueSettlementOutbox({ limit: 5 });
    expect(result.processed).toBe(1);
    expect(result.results[0].status).toBe('posted');
    expect(mockPostSettlementGLPair).toHaveBeenCalled();
  });
});
