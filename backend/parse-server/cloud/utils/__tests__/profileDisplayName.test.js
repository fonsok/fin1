'use strict';

const {
  formatProfileShortDisplayName,
  formatNameFieldsShortDisplayName,
} = require('../profileDisplayName');

describe('profileDisplayName', () => {
  test('formats first and last name', () => {
    expect(formatNameFieldsShortDisplayName('Jan', 'Becker')).toBe('Jan B.');
  });

  test('handles missing lastName (early signup profile)', () => {
    expect(formatNameFieldsShortDisplayName('Jan', null)).toBe('Jan');
    expect(formatNameFieldsShortDisplayName('Jan', undefined)).toBe('Jan');
    expect(formatNameFieldsShortDisplayName('Jan', '')).toBe('Jan');
  });

  test('handles missing firstName', () => {
    expect(formatNameFieldsShortDisplayName(null, 'Becker')).toBe('Becker');
  });

  test('uses fallback when both names missing', () => {
    expect(formatNameFieldsShortDisplayName(null, null, 'trader42')).toBe('trader42');
    expect(formatNameFieldsShortDisplayName('', '', 'Trader')).toBe('Trader');
  });

  test('formatProfileShortDisplayName reads Parse-like profile', () => {
    const profile = {
      get(key) {
        if (key === 'firstName') return 'Ada';
        if (key === 'lastName') return 'Lovelace';
        return null;
      },
    };
    expect(formatProfileShortDisplayName(profile)).toBe('Ada L.');
  });

  test('formatProfileShortDisplayName without names uses fallback', () => {
    const profile = { get: () => null };
    expect(formatProfileShortDisplayName(profile, 'mytrader')).toBe('mytrader');
    expect(formatProfileShortDisplayName(null, 'Trader')).toBe('Trader');
  });
});

describe('handleDiscoverTraders', () => {
  let handleDiscoverTraders;

  beforeEach(() => {
    jest.resetModules();
    global.Parse = {
      User: class User {},
      Query: jest.fn(),
      Object: { extend: jest.fn() },
    };
    ({ handleDiscoverTraders } = require('../../functions/investmentDiscoverTraders'));
  });

  test('does not throw when profile has no lastName', async () => {
    const trader = {
      id: 'trader-1',
      get: (key) => (key === 'username' ? 'newtrader' : key === 'status' ? 'active' : null),
    };

    class FakeQuery {
      constructor() {
        this.className = null;
      }
      equalTo() { return this; }
      descending() { return this; }
      limit() { return this; }
      skip() { return this; }
      async find() {
        if (this._kind === 'user') return [trader];
        if (this._kind === 'profile') {
          return [{
            get: (key) => (key === 'firstName' ? 'New' : null),
          }];
        }
        if (this._kind === 'risk') return [];
        if (this._kind === 'investment') return [];
        return [];
      }
      async first() {
        const rows = await this.find();
        return rows[0] || null;
      }
    }

    Parse.Query = jest.fn().mockImplementation((className) => {
      const q = new FakeQuery();
      if (className === Parse.User) q._kind = 'user';
      else if (className === 'UserProfile') q._kind = 'profile';
      else if (className === 'UserRiskAssessment') q._kind = 'risk';
      else if (className === 'Investment') q._kind = 'investment';
      return q;
    });

    const result = await handleDiscoverTraders({ params: { limit: 10, skip: 0 } });
    expect(result.traders).toHaveLength(1);
    expect(result.traders[0].displayName).toBe('New');
    expect(result.traders[0].username).toBe('newtrader');
  });
});
