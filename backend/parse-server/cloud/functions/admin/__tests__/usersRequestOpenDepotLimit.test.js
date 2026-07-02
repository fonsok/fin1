'use strict';

const { handleRequestUserOpenDepotLimitChange } = require('../usersRequestOpenDepotLimit');

jest.mock('../../../utils/configHelper/index.js', () => ({
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS: {
    limit: 'maxOpenDepotPositionsOverride',
    effectiveFrom: 'maxOpenDepotPositionsOverrideEffectiveFrom',
  },
  normalizeMaxOpenDepotPositions: jest.fn((raw) => {
    const n = Math.floor(Number(raw));
    if (!Number.isFinite(n) || n < 1 || n > 50) {
      return null;
    }
    return n;
  }),
}));

describe('usersRequestOpenDepotLimit', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    global.Parse = {
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
      User: class {},
      Object: {
        extend: jest.fn(() => class MockFourEyes {
          constructor() {
            this.data = {};
          }
          set(key, value) {
            this.data[key] = value;
          }
          save() {
            this.id = 'four-eyes-depot-1';
            return Promise.resolve(this);
          }
        }),
      },
      Query: jest.fn().mockImplementation(() => ({
        get: jest.fn().mockResolvedValue({
          id: 'user-trader-1',
          get(key) {
            if (key === 'role') return 'trader';
            if (key === 'email') return 'trader@test.com';
            if (key === 'maxOpenDepotPositionsOverride') return null;
            return undefined;
          },
        }),
      })),
    };
  });

  test('creates four-eyes request for trader open depot limit override', async () => {
    const result = await handleRequestUserOpenDepotLimitChange({
      user: { id: 'admin-1', get: () => 'admin' },
      params: {
        userId: 'user-trader-1',
        maxOpenDepotPositions: 8,
        reason: 'VIP trader capacity',
      },
    });
    expect(result.success).toBe(true);
    expect(result.requiresApproval).toBe(true);
    expect(result.fourEyesRequestId).toBe('four-eyes-depot-1');
  });

  test('rejects non-trader users', async () => {
    global.Parse.Query = jest.fn().mockImplementation(() => ({
      get: jest.fn().mockResolvedValue({
        id: 'user-investor-1',
        get(key) {
          if (key === 'role') return 'investor';
          return undefined;
        },
      }),
    }));

    await expect(handleRequestUserOpenDepotLimitChange({
      user: { id: 'admin-1', get: () => 'admin' },
      params: {
        userId: 'user-investor-1',
        maxOpenDepotPositions: 8,
        reason: 'invalid',
      },
    })).rejects.toThrow('nur für Nutzer mit Rolle trader');
  });
});
