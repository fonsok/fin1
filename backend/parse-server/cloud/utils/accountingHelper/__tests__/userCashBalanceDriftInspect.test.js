'use strict';

const mockUsers = [
  { id: 'u-aligned' },
  { id: 'u-drift' },
  { id: 'u-missing' },
];

global.Parse = {
  Query: jest.fn().mockImplementation((className) => {
    if (className !== Parse.User) {
      throw new Error(`unexpected query class ${className}`);
    }
    return {
      equalTo: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      ascending: jest.fn().mockReturnThis(),
      find: jest.fn(async () => mockUsers),
    };
  }),
  User: 'User',
};

const closingByUser = {
  'u-aligned': 9522.31,
  'u-drift': 9522.31,
  'u-missing': 10000,
};

const storedByUser = {
  'u-aligned': 9522.31,
  'u-drift': -5528.75,
  'u-missing': null,
};

const mongoByUser = {
  'u-aligned': { userId: 'u-aligned', currentBalance: 9522.31, currentBalanceCents: 952231 },
  'u-drift': { userId: 'u-drift', currentBalance: -5528.75, currentBalanceCents: -552875 },
};

jest.mock('../customerClosingBalance', () => ({
  computeCustomerClosingBalanceForUserId: jest.fn(async (userId) => closingByUser[userId]),
}));

jest.mock('../userCashBalanceAtomic', () => ({
  readStoredUserCashBalanceForUser: jest.fn(async (userId) => storedByUser[userId]),
  getUserCashBalanceCollection: jest.fn(async () => ({
    findOne: jest.fn(async (filter) => mongoByUser[filter.userId] || null),
  })),
}));

const { inspectUserCashBalanceDrift } = require('../userCashBalanceDriftInspect');

describe('inspectUserCashBalanceDrift', () => {
  test('reports aligned, drifted, and missing rows', async () => {
    const report = await inspectUserCashBalanceDrift({ limitUsers: 500 });

    expect(report.healthy).toBe(false);
    expect(report.examined).toBe(3);
    expect(report.alignedUsers).toBe(1);
    expect(report.drifted).toBe(1);
    expect(report.missingRows).toBe(1);
    expect(report.missingCents).toBe(0);
    expect(report.centsMismatch).toBe(0);
    expect(report.driftedUsers).toEqual([{
      userId: 'u-drift',
      storedBalance: -5528.75,
      customerBalance: 9522.31,
      deltaCents: 1505106,
    }]);
    expect(report.missingRowUsers).toEqual([{ userId: 'u-missing', customerBalance: 10000 }]);
  });

  test('healthy when all users align including cents field', async () => {
    storedByUser['u-drift'] = 9522.31;
    storedByUser['u-missing'] = 10000;
    mongoByUser['u-drift'] = { userId: 'u-drift', currentBalance: 9522.31, currentBalanceCents: 952231 };
    mongoByUser['u-missing'] = { userId: 'u-missing', currentBalance: 10000, currentBalanceCents: 1000000 };

    const report = await inspectUserCashBalanceDrift({ limitUsers: 500 });

    expect(report.healthy).toBe(true);
    expect(report.drifted).toBe(0);
    expect(report.missingRows).toBe(0);
    expect(report.missingCents).toBe(0);
    expect(report.centsMismatch).toBe(0);

    storedByUser['u-drift'] = -5528.75;
    storedByUser['u-missing'] = null;
    mongoByUser['u-drift'] = { userId: 'u-drift', currentBalance: -5528.75, currentBalanceCents: -552875 };
    delete mongoByUser['u-missing'];
  });

  test('flags missing currentBalanceCents', async () => {
    mongoByUser['u-aligned'] = { userId: 'u-aligned', currentBalance: 9522.31 };

    const report = await inspectUserCashBalanceDrift({ limitUsers: 500 });

    expect(report.missingCents).toBe(1);
    expect(report.healthy).toBe(false);

    mongoByUser['u-aligned'] = { userId: 'u-aligned', currentBalance: 9522.31, currentBalanceCents: 952231 };
  });
});
