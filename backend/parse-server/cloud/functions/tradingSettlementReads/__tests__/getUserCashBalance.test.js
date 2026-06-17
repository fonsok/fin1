'use strict';

class ParseError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
ParseError.INVALID_SESSION_TOKEN = 209;
global.Parse = { Error: ParseError };

jest.mock('../../../utils/accountingHelper/customerClosingBalance', () => ({
  computeCustomerClosingBalanceForUser: jest.fn(async () => 9522.31),
  auditUserCashBalanceDriftIfNeeded: jest.fn(),
}));

jest.mock('../../../utils/accountingHelper/userCashBalanceAtomic', () => ({
  readStoredUserCashBalanceForUser: jest.fn(async () => -5528.75),
}));

jest.mock('../../tradingIdentity', () => ({
  getUserStableId: jest.fn((user) => user.id),
}));

const { handleGetUserCashBalance } = require('../getUserCashBalance');
const { computeCustomerClosingBalanceForUser, auditUserCashBalanceDriftIfNeeded } = require('../../../utils/accountingHelper/customerClosingBalance');
const { readStoredUserCashBalanceForUser } = require('../../../utils/accountingHelper/userCashBalanceAtomic');

describe('handleGetUserCashBalance', () => {
  test('returns customer timeline closing balance', async () => {
    const out = await handleGetUserCashBalance({
      user: { id: 'user-1' },
    });

    expect(computeCustomerClosingBalanceForUser).toHaveBeenCalled();
    expect(out).toEqual({
      userId: 'user-1',
      currentBalance: 9522.31,
      source: 'customer_timeline',
    });
  });

  test('audits drift when stored UserCashBalance differs', async () => {
    await handleGetUserCashBalance({ user: { id: 'user-1' } });

    expect(readStoredUserCashBalanceForUser).toHaveBeenCalledWith('user-1');
    expect(auditUserCashBalanceDriftIfNeeded).toHaveBeenCalledWith('user-1', -5528.75, 9522.31);
  });

  test('requires session', async () => {
    await expect(handleGetUserCashBalance({ user: null })).rejects.toMatchObject({
      code: 209,
    });
  });
});
