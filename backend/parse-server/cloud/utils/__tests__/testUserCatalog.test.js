'use strict';

const {
  isSeedTestUserEmail,
  isSignupRunEmail,
  searchQueryTargetsSignupRuns,
  shouldExcludeSignupRuns,
} = require('../testUserCatalog');

describe('testUserCatalog', () => {
  test('identifies seed debug-list mailboxes', () => {
    expect(isSeedTestUserEmail('investor1@test.com')).toBe(true);
    expect(isSeedTestUserEmail('trader10@test.com')).toBe(true);
    expect(isSeedTestUserEmail('signup+123@test.com')).toBe(false);
  });

  test('identifies Get Started signup run mailboxes', () => {
    expect(isSignupRunEmail('signup+1781782677@test.com')).toBe(true);
    expect(isSignupRunEmail('investor1@test.com')).toBe(false);
  });

  test('shouldExcludeSignupRuns hides noise unless explicitly requested', () => {
    expect(shouldExcludeSignupRuns({})).toBe(true);
    expect(shouldExcludeSignupRuns({ testUserFilter: 'seed' })).toBe(true);
    expect(shouldExcludeSignupRuns({ testUserFilter: 'signupRuns' })).toBe(false);
    expect(shouldExcludeSignupRuns({ searchQuery: 'signup+178' })).toBe(false);
    expect(searchQueryTargetsSignupRuns('signup+178')).toBe(true);
  });
});

describe('rankSearchUsers', () => {
  const { rankSearchUsers } = require('../../functions/admin/usersSearchUsers');

  function mockUser({ id, email, username, customerNumber, createdAt }) {
    return {
      id,
      get(key) {
        const data = {
          email,
          username: username || email,
          customerNumber,
          createdAt: createdAt || new Date('2026-06-20T12:00:00Z'),
        };
        return data[key];
      },
    };
  }

  test('prioritizes exact email and seed debug users over signup runs', () => {
    const users = [
      mockUser({ id: 'a', email: 'signup+1@test.com', createdAt: new Date('2026-06-20T13:00:00Z') }),
      mockUser({ id: 'b', email: 'investor1@test.com', customerNumber: 'ANL-2026-00001' }),
      mockUser({ id: 'c', email: 'other@test.com' }),
    ];

    const ranked = rankSearchUsers(users, 'Maximilian');
    expect(ranked.map((u) => u.id)).toEqual(['b', 'c', 'a']);
  });

  test('exact email match wins', () => {
    const users = [
      mockUser({ id: 'a', email: 'investor2@test.com' }),
      mockUser({ id: 'b', email: 'investor1@test.com' }),
    ];
    const ranked = rankSearchUsers(users, 'investor1@test.com');
    expect(ranked[0].id).toBe('b');
  });
});
