'use strict';

const auditCalls = [];
jest.mock('../../../utils/structuredLogger', () => ({
  audit: {
    info: (event, fields) => auditCalls.push({ event, fields }),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

const mockUsers = [
  { id: 'u1' },
  { id: 'u2' },
];

global.Parse = {
  Query: jest.fn().mockImplementation((className) => {
    if (className !== Parse.User) {
      throw new Error(`unexpected query class ${className}`);
    }
    return {
      limit: jest.fn().mockReturnThis(),
      ascending: jest.fn().mockReturnThis(),
      find: jest.fn(async () => mockUsers),
    };
  }),
  User: 'User',
};

const mockUpdates = [];
const mockBalCollection = {
  updateOne: jest.fn(async (filter, update, opts) => {
    mockUpdates.push({ filter, update, opts });
    return { acknowledged: true };
  }),
};

const closingByUser = {
  u1: 9522.31,
  u2: 100,
};

jest.mock('../../../utils/accountingHelper/userCashBalanceAtomic', () => ({
  getUserCashBalanceCollection: jest.fn(async () => mockBalCollection),
}));

jest.mock('../../../utils/accountingHelper/customerClosingBalance', () => ({
  computeCustomerClosingBalanceForUserId: jest.fn(async (userId) => closingByUser[userId]),
}));

const { handleBackfillUserCashBalanceFromStatements } = require('../financialUserCashBalanceBackfill');

describe('backfillUserCashBalanceFromStatements', () => {
  beforeEach(() => {
    auditCalls.length = 0;
    mockUpdates.length = 0;
    mockBalCollection.updateOne.mockClear();
  });

  test('dryRun previews customer timeline closing per user', async () => {
    const out = await handleBackfillUserCashBalanceFromStatements({ params: { dryRun: true } });

    expect(out.basis).toBe('customer_timeline');
    expect(out.usersProcessed).toBe(2);
    expect(out.writesPerformed).toBe(0);
    expect(out.preview).toEqual(expect.arrayContaining([
      { userId: 'u1', currentBalanceTarget: 9522.31 },
      { userId: 'u2', currentBalanceTarget: 100 },
    ]));
    expect(mockUpdates).toHaveLength(0);
  });

  test('live run upserts UserCashBalance from customer timeline', async () => {
    const out = await handleBackfillUserCashBalanceFromStatements({ params: { dryRun: false } });

    expect(out.writesPerformed).toBe(2);
    expect(mockUpdates).toHaveLength(2);

    const u1Update = mockUpdates.find((u) => u.filter.userId === 'u1');
    expect(u1Update.update).toEqual({
      $set: { userId: 'u1', currentBalance: 9522.31, currentBalanceCents: 952231 },
    });
    expect(u1Update.opts).toEqual({ upsert: true });

    expect(auditCalls.some((c) => c.event === 'admin.userCashBalance.backfill')).toBe(true);
  });
});
