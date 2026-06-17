'use strict';

class ParseError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
ParseError.INVALID_SESSION_TOKEN = 209;
global.Parse = { Error: ParseError };

jest.mock('../../../utils/accountingHelper/userCashBalanceAtomic', () => ({
  readUserCashBalanceForUser: jest.fn(async (userId) => (userId === 'user-1' ? 1234.56 : 0)),
}));

jest.mock('../../tradingIdentity', () => ({
  getUserStableId: jest.fn((user) => user.id),
}));

const { handleGetUserCashBalance } = require('../getUserCashBalance');
const { readUserCashBalanceForUser } = require('../../../utils/accountingHelper/userCashBalanceAtomic');

describe('handleGetUserCashBalance', () => {
  test('returns UserCashBalance SSOT for logged-in user', async () => {
    const out = await handleGetUserCashBalance({
      user: { id: 'user-1' },
    });

    expect(readUserCashBalanceForUser).toHaveBeenCalledWith('user-1');
    expect(out).toEqual({
      userId: 'user-1',
      currentBalance: 1234.56,
      source: 'UserCashBalance',
    });
  });

  test('requires session', async () => {
    await expect(handleGetUserCashBalance({ user: null })).rejects.toMatchObject({
      code: 209,
    });
  });
});
