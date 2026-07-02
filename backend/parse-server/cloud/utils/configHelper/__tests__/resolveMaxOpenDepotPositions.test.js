'use strict';

const {
  normalizeMaxOpenDepotPositions,
  readUserMaxOpenDepotPositionsOverride,
  resolveMaxOpenDepotPositions,
  USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS,
} = require('../resolveMaxOpenDepotPositions');

jest.mock('../loadConfig', () => ({
  loadConfig: jest.fn().mockResolvedValue({
    financial: { maxTraderOpenDepotPositions: 5 },
  }),
}));

jest.mock('../cache', () => ({
  peekCacheOrNull: jest.fn(() => null),
}));

describe('resolveMaxOpenDepotPositions', () => {
  test('normalize accepts integers in range', () => {
    expect(normalizeMaxOpenDepotPositions(5)).toBe(5);
    expect(normalizeMaxOpenDepotPositions(1)).toBe(1);
    expect(normalizeMaxOpenDepotPositions(50)).toBe(50);
    expect(normalizeMaxOpenDepotPositions(0)).toBeNull();
    expect(normalizeMaxOpenDepotPositions(51)).toBeNull();
  });

  test('readUserMaxOpenDepotPositionsOverride respects effectiveFrom', () => {
    const user = {
      get(key) {
        if (key === USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit) return 10;
        if (key === USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.effectiveFrom) {
          return new Date('2099-01-01');
        }
        return undefined;
      },
    };
    expect(readUserMaxOpenDepotPositionsOverride(user, new Date('2026-01-01'))).toBeNull();
    expect(readUserMaxOpenDepotPositionsOverride(user, new Date('2100-01-01'))).toBe(10);
  });

  test('resolveMaxOpenDepotPositions prefers trader override', async () => {
    const result = await resolveMaxOpenDepotPositions({
      traderId: 'trader-1',
    }, {
      fetchUser: async () => ({
        get(key) {
          if (key === USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.limit) return 12;
          if (key === USER_OPEN_DEPOT_LIMIT_OVERRIDE_FIELDS.effectiveFrom) {
            return new Date('2020-01-01');
          }
          return undefined;
        },
      }),
    });
    expect(result).toEqual({ limit: 12, source: 'trader' });
  });

  test('resolveMaxOpenDepotPositions falls back to global', async () => {
    const result = await resolveMaxOpenDepotPositions({ traderId: 'trader-2' }, {
      fetchUser: async () => ({
        get() {
          return undefined;
        },
      }),
    });
    expect(result).toEqual({ limit: 5, source: 'global' });
  });
});
