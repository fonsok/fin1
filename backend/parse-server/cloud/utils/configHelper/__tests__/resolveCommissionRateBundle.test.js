'use strict';

jest.mock('../getters', () => ({
  getCommissionRateBundle: jest.fn().mockResolvedValue({
    traderRate: 0.05,
    appRate: 0.05,
    totalRate: 0.1,
  }),
}));

const { getCommissionRateBundle } = require('../getters');
const {
  USER_COMMISSION_OVERRIDE_FIELDS,
  readUserCommissionRateOverride,
  resolveCommissionRateBundle,
  createCommissionRateResolver,
  effectiveCommissionRateFromAmount,
} = require('../resolveCommissionRateBundle');

function makeUser(overrides = {}) {
  const data = {
    [USER_COMMISSION_OVERRIDE_FIELDS.bundle]: {
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.07,
      appCommissionRate: 0.03,
    },
    [USER_COMMISSION_OVERRIDE_FIELDS.role]: 'trader',
    [USER_COMMISSION_OVERRIDE_FIELDS.effectiveFrom]: new Date('2020-01-01'),
    ...overrides,
  };
  return {
    get(key) {
      return data[key];
    },
  };
}

describe('resolveCommissionRateBundle', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('readUserCommissionRateOverride', () => {
    it('returns null when user is missing', () => {
      expect(readUserCommissionRateOverride(null, 'trader')).toBeNull();
    });

    it('rejects override when role does not match', () => {
      const user = makeUser({ [USER_COMMISSION_OVERRIDE_FIELDS.role]: 'investor' });
      expect(readUserCommissionRateOverride(user, 'trader')).toBeNull();
    });

    it('rejects override before effectiveFrom', () => {
      const user = makeUser({
        [USER_COMMISSION_OVERRIDE_FIELDS.effectiveFrom]: new Date('2099-01-01'),
      });
      expect(readUserCommissionRateOverride(user, 'trader', new Date('2026-01-01'))).toBeNull();
    });

    it('accepts valid trader override', () => {
      const user = makeUser();
      const result = readUserCommissionRateOverride(user, 'trader');
      expect(result).toEqual({
        bundle: {
          investorCommissionRateTotal: 0.1,
          traderCommissionRate: 0.07,
          appCommissionRate: 0.03,
        },
        role: 'trader',
      });
    });
  });

  describe('resolveCommissionRateBundle', () => {
    it('returns global rates when no overrides apply', async () => {
      const fetchUser = jest.fn().mockResolvedValue(null);
      const result = await resolveCommissionRateBundle(
        { traderId: 't1', investorId: 'i1' },
        { fetchUser },
      );
      expect(result).toMatchObject({
        traderRate: 0.05,
        appRate: 0.05,
        totalRate: 0.1,
        source: 'global',
      });
      expect(fetchUser).toHaveBeenCalledWith('i1');
      expect(fetchUser).toHaveBeenCalledWith('t1');
    });

    it('prefers investment snapshot over user overrides', async () => {
      const investment = {
        get(key) {
          if (key === 'commissionRateBundleSnapshot') {
            return {
              investorCommissionRateTotal: 0.09,
              traderCommissionRate: 0.04,
              appCommissionRate: 0.05,
            };
          }
          return undefined;
        },
      };
      const fetchUser = jest.fn();
      const result = await resolveCommissionRateBundle(
        { traderId: 't1', investorId: 'i1', investment },
        { fetchUser },
      );
      expect(result.source).toBe('investment_snapshot');
      expect(result.totalRate).toBe(0.09);
      expect(fetchUser).not.toHaveBeenCalled();
    });

    it('prefers investor override over trader override', async () => {
      const investorUser = makeUser({
        [USER_COMMISSION_OVERRIDE_FIELDS.role]: 'investor',
        [USER_COMMISSION_OVERRIDE_FIELDS.bundle]: {
          investorCommissionRateTotal: 0.08,
          traderCommissionRate: 0.04,
          appCommissionRate: 0.04,
        },
      });
      const traderUser = makeUser();
      const fetchUser = jest.fn(async (id) => {
        if (id === 'i1') return investorUser;
        if (id === 't1') return traderUser;
        return null;
      });

      const result = await resolveCommissionRateBundle(
        { traderId: 't1', investorId: 'i1' },
        { fetchUser },
      );

      expect(result.source).toBe('investor');
      expect(result.totalRate).toBe(0.08);
      expect(result.traderRate).toBe(0.04);
      expect(fetchUser).toHaveBeenCalledTimes(1);
    });

    it('uses trader override when investor has none', async () => {
      const traderUser = makeUser();
      const fetchUser = jest.fn(async (id) => (id === 't1' ? traderUser : null));

      const result = await resolveCommissionRateBundle(
        { traderId: 't1', investorId: 'i1' },
        { fetchUser },
      );

      expect(result.source).toBe('trader');
      expect(result.traderRate).toBe(0.07);
      expect(result.appRate).toBe(0.03);
      expect(fetchUser).toHaveBeenCalledTimes(2);
    });
  });

  describe('createCommissionRateResolver', () => {
    it('caches trader user fetches across resolve calls', async () => {
      const traderUser = makeUser();
      const fetchUser = jest.fn(async (id) => {
        if (id === 't1') return traderUser;
        return null;
      });
      const resolver = await createCommissionRateResolver({ fetchUser });

      await resolver.resolve({ traderId: 't1', investorId: 'i-none' });
      await resolver.resolve({ traderId: 't1', investorId: 'i-none-2' });

      const traderFetches = fetchUser.mock.calls.filter(([id]) => id === 't1');
      expect(traderFetches).toHaveLength(1);
    });
  });

  describe('effectiveCommissionRateFromAmount', () => {
    it('computes weighted rate from amounts', () => {
      expect(effectiveCommissionRateFromAmount(70, 1000, 0.05)).toBe(0.07);
    });

    it('falls back when basis is zero', () => {
      expect(effectiveCommissionRateFromAmount(0, 0, 0.05)).toBe(0.05);
    });
  });
});

describe('getCommissionRateBundle integration', () => {
  it('is used as global fallback', async () => {
    await resolveCommissionRateBundle({}, { fetchUser: jest.fn() });
    expect(getCommissionRateBundle).toHaveBeenCalled();
  });
});
