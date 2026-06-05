'use strict';

const {
  looksLikeParseObjectId,
  isLegacyStableUserId,
  emailFromLegacyStableUserId,
  getCanonicalUserId,
  collectLedgerUserIdCandidates,
} = require('../canonicalUserId');

describe('canonicalUserId', () => {
  test('looksLikeParseObjectId', () => {
    expect(looksLikeParseObjectId('yqpmpTiBK9')).toBe(true);
    expect(looksLikeParseObjectId('user:investor5@test.com')).toBe(false);
  });

  test('legacy stable id parsing', () => {
    expect(isLegacyStableUserId('user:investor5@test.com')).toBe(true);
    expect(emailFromLegacyStableUserId('user:investor5@test.com')).toBe('investor5@test.com');
  });

  test('getCanonicalUserId returns objectId only', () => {
    const user = { id: 'abc123XYZ0', get: (k) => (k === 'email' ? 'investor5@test.com' : undefined) };
    expect(getCanonicalUserId(user)).toBe('abc123XYZ0');
  });

  test('collectLedgerUserIdCandidates includes objectId and legacy alias', () => {
    const user = {
      id: 'abc123XYZ0',
      get: (k) => {
        if (k === 'email') return 'investor5@test.com';
        if (k === 'stableId') return undefined;
        return undefined;
      },
    };
    const keys = collectLedgerUserIdCandidates(user);
    expect(keys).toContain('abc123XYZ0');
    expect(keys).toContain('user:investor5@test.com');
  });
});
