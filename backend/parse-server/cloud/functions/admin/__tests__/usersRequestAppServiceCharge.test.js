'use strict';

const { handleRequestUserAppServiceChargeChange } = require('../usersRequestAppServiceCharge');

jest.mock('../../../utils/configHelper/index.js', () => ({
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS: {
    rate: 'appServiceChargeRateOverride',
    effectiveFrom: 'appServiceChargeOverrideEffectiveFrom',
  },
  normalizeAppServiceChargeRate: jest.fn((raw) => {
    const rate = Number(raw);
    if (!Number.isFinite(rate) || rate < 0 || rate > 0.1) {
      return null;
    }
    return rate;
  }),
}));

describe('usersRequestAppServiceCharge', () => {
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
            this.id = 'four-eyes-asc-1';
            return Promise.resolve(this);
          }
        }),
      },
      Query: jest.fn().mockImplementation(() => ({
        get: jest.fn().mockResolvedValue({
          id: 'user-investor-1',
          get(key) {
            if (key === 'role') return 'investor';
            if (key === 'email') return 'investor@test.com';
            if (key === 'appServiceChargeRateOverride') return null;
            return undefined;
          },
        }),
      })),
    };
  });

  test('creates four-eyes request for investor app service charge override', async () => {
    const result = await handleRequestUserAppServiceChargeChange({
      user: { id: 'admin-1', get: () => 'admin' },
      params: {
        userId: 'user-investor-1',
        appServiceChargeRate: 0.015,
        reason: 'VIP investor terms',
      },
    });
    expect(result.success).toBe(true);
    expect(result.requiresApproval).toBe(true);
    expect(result.fourEyesRequestId).toBe('four-eyes-asc-1');
  });

  test('rejects non-investor users', async () => {
    global.Parse.Query = jest.fn().mockImplementation(() => ({
      get: jest.fn().mockResolvedValue({
        id: 'user-trader-1',
        get(key) {
          if (key === 'role') return 'trader';
          return undefined;
        },
      }),
    }));

    await expect(handleRequestUserAppServiceChargeChange({
      user: { id: 'admin-1', get: () => 'admin' },
      params: {
        userId: 'user-trader-1',
        appServiceChargeRate: 0.015,
        reason: 'invalid',
      },
    })).rejects.toThrow('nur für Nutzer mit Rolle investor');
  });
});
