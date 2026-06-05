'use strict';

// =============================================================================
// Regression test for `backfillUserCashBalanceFromStatements`.
//
// Background: an earlier implementation used a Mongo aggregation with
// `$sort + $group + $last` to pick the closing balance per user. That pattern is
// non-deterministic on Mongo 4.x AND assumes a `createdAt` field — Parse stores
// timestamps as `_created_at` in the underlying Mongo collection. The fix:
// (a) iterate `userId`s via `distinct`, (b) per user, `findOne` with explicit
// `sort({_created_at: -1, _id: -1})`. This test pins both invariants.
// =============================================================================

const auditCalls = [];
jest.mock('../../../utils/structuredLogger', () => ({
  audit: {
    info: (event, fields) => auditCalls.push({ event, fields }),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

let lastSortReceived;
let lastProjectionReceived;

const mockStmtRowsByUser = {
  u1: [
    { _id: 'a', _created_at: new Date('2026-01-01T10:00:00Z'), balanceAfter: -1000 },
    { _id: 'b', _created_at: new Date('2026-01-01T10:01:00Z'), balanceAfter: -998 },
    { _id: 'c', _created_at: new Date('2026-01-01T10:02:00Z'), balanceAfter: 506.5 },
    { _id: 'd', _created_at: new Date('2026-01-01T10:02:01Z'), balanceAfter: 450.22 },
  ],
  u2: [
    { _id: 'x', _created_at: new Date('2026-02-01T08:00:00Z'), balanceAfter: 100 },
  ],
};

const mockUpdates = [];

const mockStmtCollection = {
  distinct: jest.fn(async () => Object.keys(mockStmtRowsByUser)),
  find: jest.fn((filter) => {
    const userId = filter && filter.userId;
    let chain = (mockStmtRowsByUser[userId] || []).slice();
    let projection = null;
    let sortKey = null;
    let limitN = Infinity;
    return {
      project(p) { projection = p; lastProjectionReceived = p; return this; },
      sort(s) { sortKey = s; lastSortReceived = s; return this; },
      limit(n) { limitN = n; return this; },
      async next() {
        if (sortKey) {
          const [primaryField, primaryDir] = Object.entries(sortKey)[0];
          chain.sort((a, b) => {
            const av = a[primaryField];
            const bv = b[primaryField];
            if (av < bv) return -primaryDir;
            if (av > bv) return primaryDir;
            return 0;
          });
        }
        const cut = chain.slice(0, limitN);
        if (projection) {
          return cut.length ? cut[0] : null;
        }
        return cut[0] || null;
      },
    };
  }),
};

const mockBalCollection = {
  updateOne: jest.fn(async (filter, update, opts) => {
    mockUpdates.push({ filter, update, opts });
    return { acknowledged: true };
  }),
};

jest.mock('../../../utils/accountingHelper/userCashBalanceAtomic', () => ({
  getAccountStatementMongoCollection: jest.fn(async () => mockStmtCollection),
  getUserCashBalanceCollection: jest.fn(async () => mockBalCollection),
}));

const { handleBackfillUserCashBalanceFromStatements } = require('../financialUserCashBalanceBackfill');

describe('backfillUserCashBalanceFromStatements', () => {
  beforeEach(() => {
    auditCalls.length = 0;
    mockUpdates.length = 0;
    lastSortReceived = null;
    lastProjectionReceived = null;
    mockStmtCollection.distinct.mockClear();
    mockStmtCollection.find.mockClear();
    mockBalCollection.updateOne.mockClear();
  });

  test('dryRun returns latest balanceAfter per user (sorted by _created_at desc, _id desc)', async () => {
    const out = await handleBackfillUserCashBalanceFromStatements({ params: { dryRun: true } });
    expect(out.usersProcessed).toBe(2);
    expect(out.writesPerformed).toBe(0);
    expect(out.preview).toEqual(expect.arrayContaining([
      { userId: 'u1', currentBalanceTarget: 450.22 },
      { userId: 'u2', currentBalanceTarget: 100 },
    ]));
    expect(mockUpdates).toHaveLength(0);
    expect(lastSortReceived).toEqual({ _created_at: -1, _id: -1 });
    expect(lastProjectionReceived).toEqual({ balanceAfter: 1, _created_at: 1, _id: 1 });
  });

  test('live run upserts UserCashBalance.currentBalance per user', async () => {
    const out = await handleBackfillUserCashBalanceFromStatements({ params: { dryRun: false } });
    expect(out.writesPerformed).toBe(2);
    expect(mockUpdates).toHaveLength(2);

    const u1Update = mockUpdates.find((u) => u.filter.userId === 'u1');
    expect(u1Update).toBeDefined();
    expect(u1Update.update).toEqual({ $set: { userId: 'u1', currentBalance: 450.22 } });
    expect(u1Update.opts).toEqual({ upsert: true });

    const u2Update = mockUpdates.find((u) => u.filter.userId === 'u2');
    expect(u2Update.update.$set.currentBalance).toBe(100);

    expect(auditCalls.some((c) => c.event === 'admin.userCashBalance.backfill')).toBe(true);
  });
});
