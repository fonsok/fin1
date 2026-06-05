'use strict';

// =============================================================================
// Tests for `auditChainConsistencyOnInsert` (Balance-Race Phase 3a).
//
// Detection-only behaviour: after a row is saved by `bookAccountStatementEntry`,
// the guard re-reads the two most recent rows for the same userId and emits a
// structured `accountstatement.balance.chainBreak` audit when the chain is
// broken (i.e. the inserted row's `balanceBefore` does not match the previous
// row's `balanceAfter`). Never throws, never mutates the row.
// =============================================================================

const auditEvents = [];

jest.mock('../../structuredLogger', () => ({
  audit: {
    info: (event, fields) => auditEvents.push({ level: 'info', event, fields }),
    warn: (event, fields) => auditEvents.push({ level: 'warn', event, fields }),
    error: (event, fields) => auditEvents.push({ level: 'error', event, fields }),
  },
}));

describe('auditChainConsistencyOnInsert (accountStatementChainGuard.js)', () => {
  let recentRowsByUserId;

  class FakeRow {
    constructor(id, attrs) {
      this.id = id;
      this.attrs = attrs || {};
    }
    get(field) { return this.attrs[field]; }
  }

  class FakeQuery {
    constructor() { this.filters = {}; this.limitValue = 100; }
    equalTo(field, value) { this.filters[field] = value; return this; }
    descending() { return this; }
    limit(n) { this.limitValue = n; return this; }
    async find() {
      const userId = this.filters.userId;
      const rows = recentRowsByUserId[userId] || [];
      return rows.slice(0, this.limitValue);
    }
  }

  beforeEach(() => {
    auditEvents.length = 0;
    recentRowsByUserId = {};
    global.Parse = { Query: FakeQuery };
  });

  function loadGuard() {
    jest.resetModules();
    return require('../accountStatementChainGuard');
  }

  test('does nothing when the chain is consistent', async () => {
    const inserted = new FakeRow('stmt-2', { balanceBefore: 100, balanceAfter: 150 });
    recentRowsByUserId['u1'] = [
      inserted,
      new FakeRow('stmt-1', { balanceBefore: 0, balanceAfter: 100 }),
    ];

    const { auditChainConsistencyOnInsert } = loadGuard();
    await auditChainConsistencyOnInsert({
      userId: 'u1',
      insertedEntry: inserted,
      entryType: 'deposit',
      amount: 50,
    });

    expect(auditEvents).toHaveLength(0);
  });

  test('does nothing on the very first entry for a user', async () => {
    const inserted = new FakeRow('stmt-1', { balanceBefore: 0, balanceAfter: 50 });
    recentRowsByUserId['u1'] = [inserted];

    const { auditChainConsistencyOnInsert } = loadGuard();
    await auditChainConsistencyOnInsert({
      userId: 'u1',
      insertedEntry: inserted,
      entryType: 'deposit',
      amount: 50,
    });

    expect(auditEvents).toHaveLength(0);
  });

  test('emits chainBreak audit when previous.balanceAfter != inserted.balanceBefore', async () => {
    const inserted = new FakeRow('stmt-2', {
      balanceBefore: 100,
      balanceAfter: 150,
      entryType: 'commission_debit',
      tradeId: 't-1',
      investmentId: 'i-1',
    });
    recentRowsByUserId['u1'] = [
      inserted,
      new FakeRow('stmt-1', { balanceBefore: 0, balanceAfter: 80 }),
    ];

    const { auditChainConsistencyOnInsert } = loadGuard();
    await auditChainConsistencyOnInsert({
      userId: 'u1',
      insertedEntry: inserted,
      entryType: 'commission_debit',
      amount: 50,
      tradeId: 't-1',
      investmentId: 'i-1',
      businessCaseId: 'bc-9',
    });

    expect(auditEvents).toHaveLength(1);
    expect(auditEvents[0].level).toBe('warn');
    expect(auditEvents[0].event).toBe('accountstatement.balance.chainBreak');
    expect(auditEvents[0].fields).toMatchObject({
      userId: 'u1',
      newestEntryId: 'stmt-2',
      previousEntryId: 'stmt-1',
      previousBalanceAfter: 80,
      newestBalanceBefore: 100,
      delta: 20,
      entryType: 'commission_debit',
      tradeId: 't-1',
      investmentId: 'i-1',
      businessCaseId: 'bc-9',
    });
  });

  test('stays silent when another writer inserted a newer row in between', async () => {
    const ourRow = new FakeRow('stmt-mine', { balanceBefore: 100, balanceAfter: 150 });
    recentRowsByUserId['u1'] = [
      new FakeRow('stmt-newer', { balanceBefore: 150, balanceAfter: 200 }),
      ourRow,
    ];

    const { auditChainConsistencyOnInsert } = loadGuard();
    await auditChainConsistencyOnInsert({
      userId: 'u1',
      insertedEntry: ourRow,
      entryType: 'deposit',
      amount: 50,
    });

    expect(auditEvents).toHaveLength(0);
  });

  test('treats sub-cent drift inside FLOAT_TOLERANCE as clean', async () => {
    const inserted = new FakeRow('stmt-2', { balanceBefore: 100.001, balanceAfter: 150 });
    recentRowsByUserId['u1'] = [
      inserted,
      new FakeRow('stmt-1', { balanceBefore: 0, balanceAfter: 100 }),
    ];

    const { auditChainConsistencyOnInsert } = loadGuard();
    await auditChainConsistencyOnInsert({
      userId: 'u1',
      insertedEntry: inserted,
      entryType: 'deposit',
      amount: 50,
    });

    expect(auditEvents).toHaveLength(0);
  });

  test('does not throw if the verification query fails', async () => {
    global.Parse = {
      Query: class {
        equalTo() { return this; }
        descending() { return this; }
        limit() { return this; }
        async find() { throw new Error('mongo down'); }
      },
    };

    const inserted = new FakeRow('stmt-x', { balanceBefore: 0, balanceAfter: 10 });
    const { auditChainConsistencyOnInsert } = loadGuard();
    await expect(auditChainConsistencyOnInsert({
      userId: 'u1',
      insertedEntry: inserted,
      entryType: 'deposit',
      amount: 10,
    })).resolves.toBeUndefined();

    expect(auditEvents.some((e) => e.event === 'accountstatement.balance.chainBreak.guardFailure')).toBe(true);
  });

  test('ignores call when userId or insertedEntry is missing', async () => {
    const { auditChainConsistencyOnInsert } = loadGuard();
    await auditChainConsistencyOnInsert({ userId: '', insertedEntry: null });
    await auditChainConsistencyOnInsert({ userId: 'u1', insertedEntry: { id: '' } });
    expect(auditEvents).toHaveLength(0);
  });
});
