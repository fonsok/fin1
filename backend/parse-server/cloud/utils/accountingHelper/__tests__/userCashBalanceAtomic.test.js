'use strict';

const mockFindOneAndUpdate = jest.fn();
const mockConnect = jest.fn().mockResolvedValue(undefined);
const mockClose = jest.fn().mockResolvedValue(undefined);

jest.mock('mongodb', () => ({
  MongoClient: jest.fn().mockImplementation(() => ({
    connect: mockConnect,
    db: jest.fn().mockReturnValue({
      collection: jest.fn().mockImplementation((name) => {
        if (name !== 'UserCashBalance') {
          return { findOneAndUpdate: jest.fn() };
        }
        return { findOneAndUpdate: mockFindOneAndUpdate };
      }),
    }),
    close: mockClose,
  })),
}));

class ParseQuery {
  constructor(className) {
    this.className = className;
  }
  equalTo() { return this; }
  descending() { return this; }
  async first() {
    if (this.className === 'UserCashBalance') {
      return { id: 'existing-ucb', get: () => 0 };
    }
    return undefined;
  }
}

describe('userCashBalanceAtomic (Phase 3b)', () => {
  beforeEach(async () => {
    mockFindOneAndUpdate.mockReset();
    mockConnect.mockClear();
    mockClose.mockClear();
    process.env.PARSE_SERVER_DATABASE_URI = 'mongodb://127.0.0.1:27017/fin1_jest_atomic';

    global.Parse = {
      Object: {
        extend() {
          return class {};
        },
      },
      Query: ParseQuery,
    };

    try {
      // eslint-disable-next-line global-require
      const u = require('../userCashBalanceAtomic');
      await u.__resetUserCashBalanceMongoForTests();
    } catch {
      // first run: module may not be loaded yet
    }
  });

  afterEach(async () => {
    // eslint-disable-next-line global-require
    const u = require('../userCashBalanceAtomic');
    await u.__resetUserCashBalanceMongoForTests();
    delete process.env.PARSE_SERVER_DATABASE_URI;
  });

  test('advanceUserCashBalanceAtomic uses Mongo pre-image as balanceBefore', async () => {
    mockFindOneAndUpdate.mockResolvedValueOnce({ value: { userId: 'u1', currentBalance: 100 } });
    // eslint-disable-next-line global-require
    const { advanceUserCashBalanceAtomic } = require('../userCashBalanceAtomic');

    const out = await advanceUserCashBalanceAtomic({ userId: 'u1', amount: -25 });
    expect(out.balanceBefore).toBe(100);
    expect(out.balanceAfter).toBe(75);
    expect(mockFindOneAndUpdate).toHaveBeenCalledWith(
      { userId: 'u1' },
      { $inc: { currentBalance: -25 } },
      { upsert: true, returnDocument: 'before' },
    );
  });

  test('advanceUserCashBalanceAtomic treats null pre-image as balanceBefore 0', async () => {
    mockFindOneAndUpdate.mockResolvedValueOnce({ value: null });
    // eslint-disable-next-line global-require
    const { advanceUserCashBalanceAtomic } = require('../userCashBalanceAtomic');

    const out = await advanceUserCashBalanceAtomic({ userId: 'u2', amount: 50 });
    expect(out.balanceBefore).toBe(0);
    expect(out.balanceAfter).toBe(50);
  });
});
