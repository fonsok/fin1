'use strict';

const { handleRequestUserCommissionRateBundleChange } = require('../usersRequestCommissionRateBundle');

jest.mock('../../../utils/configHelper/commissionRateBundle', () => ({
  validateCommissionRateBundle: jest.fn((bundle) => ({
    valid: bundle.traderCommissionRate + bundle.appCommissionRate
      === bundle.investorCommissionRateTotal,
    bundle,
    error: 'invalid',
  })),
  normalizeCommissionRateBundle: jest.fn((raw) => raw || null),
  formatCommissionRateBundle: jest.fn(() => '10 % gesamt'),
}));

describe('usersRequestCommissionRateBundle', () => {
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
            this.id = 'four-eyes-1';
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
            if (key === 'commissionRateBundleOverride') return null;
            return undefined;
          },
        }),
      })),
    };
  });

  test('creates four-eyes request for trader override', async () => {
    const result = await handleRequestUserCommissionRateBundleChange({
      user: { id: 'admin-1', get: () => 'admin' },
      params: {
        userId: 'user-trader-1',
        investorCommissionRateTotal: 0.1,
        traderCommissionRate: 0.07,
        appCommissionRate: 0.03,
        reason: 'Star trader retention',
      },
    });
    expect(result.success).toBe(true);
    expect(result.requiresApproval).toBe(true);
    expect(result.fourEyesRequestId).toBe('four-eyes-1');
  });
});
