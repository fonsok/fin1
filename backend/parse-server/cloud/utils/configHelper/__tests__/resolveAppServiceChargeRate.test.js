'use strict';

jest.mock('../getters', () => ({
  getAppServiceChargeRateForAccountType: jest.fn().mockResolvedValue(0.02),
}));

jest.mock('../validateConfigValue', () => ({
  validateConfigValue: jest.fn((_name, rate) => ({
    valid: Number.isFinite(rate) && rate >= 0 && rate <= 0.1,
  })),
}));

const { getAppServiceChargeRateForAccountType } = require('../getters');
const {
  USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS,
  readUserAppServiceChargeOverride,
  resolveAppServiceChargeRate,
  createAppServiceChargeResolver,
} = require('../resolveAppServiceChargeRate');

function makeUser(overrides = {}) {
  const data = {
    [USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate]: 0.015,
    [USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.effectiveFrom]: new Date('2020-01-01'),
    ...overrides,
  };
  return {
    get(key) {
      return data[key];
    },
  };
}

describe('resolveAppServiceChargeRate', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('readUserAppServiceChargeOverride', () => {
    it('returns null when user is missing', () => {
      expect(readUserAppServiceChargeOverride(null)).toBeNull();
    });

    it('rejects override before effectiveFrom', () => {
      const user = makeUser({
        [USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.effectiveFrom]: new Date('2099-01-01'),
      });
      expect(readUserAppServiceChargeOverride(user, new Date('2026-01-01'))).toBeNull();
    });

    it('accepts valid investor override', () => {
      const user = makeUser();
      expect(readUserAppServiceChargeOverride(user)).toBe(0.015);
    });
  });

  describe('resolveAppServiceChargeRate', () => {
    it('returns global rate when no investor override applies', async () => {
      const fetchUser = jest.fn().mockResolvedValue(null);
      const result = await resolveAppServiceChargeRate(
        { investorId: 'i1', accountType: 'individual' },
        { fetchUser },
      );
      expect(result).toEqual({ rate: 0.02, source: 'global' });
      expect(fetchUser).toHaveBeenCalledWith('i1');
      expect(getAppServiceChargeRateForAccountType).toHaveBeenCalledWith('individual');
    });

    it('uses investor override when set', async () => {
      const investorUser = makeUser({ [USER_APP_SERVICE_CHARGE_OVERRIDE_FIELDS.rate]: 0.01 });
      const fetchUser = jest.fn().mockResolvedValue(investorUser);

      const result = await resolveAppServiceChargeRate(
        { investorId: 'i1', accountType: 'company' },
        { fetchUser },
      );

      expect(result).toEqual({ rate: 0.01, source: 'investor' });
    });

    it('uses company global rate when no override', async () => {
      getAppServiceChargeRateForAccountType.mockResolvedValueOnce(0.025);
      const result = await resolveAppServiceChargeRate(
        { investorId: 'i1', accountType: 'company' },
        { fetchUser: jest.fn().mockResolvedValue(null) },
      );
      expect(result).toEqual({ rate: 0.025, source: 'global' });
      expect(getAppServiceChargeRateForAccountType).toHaveBeenCalledWith('company');
    });
  });

  describe('createAppServiceChargeResolver', () => {
    it('caches investor user fetches across resolve calls', async () => {
      const investorUser = makeUser();
      const fetchUser = jest.fn().mockResolvedValue(investorUser);
      const resolver = await createAppServiceChargeResolver({ fetchUser });

      await resolver.resolve({ investorId: 'i1', accountType: 'individual' });
      await resolver.resolve({ investorId: 'i1', accountType: 'individual' });

      expect(fetchUser).toHaveBeenCalledTimes(1);
    });
  });
});
