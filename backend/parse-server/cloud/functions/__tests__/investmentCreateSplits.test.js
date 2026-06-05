'use strict';

const {
  amountsMatch,
  isDuplicateKeyError,
  splitResultFromInvestment,
} = require('../investmentCreateSplits');

describe('investmentCreateSplits helpers', () => {
  test('amountsMatch within epsilon', () => {
    expect(amountsMatch(100, 100.009)).toBe(true);
    expect(amountsMatch(100, 100.05)).toBe(false);
  });

  test('isDuplicateKeyError detects Parse and Mongo duplicate signals', () => {
    expect(isDuplicateKeyError({ code: 137, message: 'duplicate' })).toBe(true);
    expect(isDuplicateKeyError({ code: 137 })).toBe(true);
    expect(isDuplicateKeyError({ message: 'E11000 duplicate key' })).toBe(true);
    expect(isDuplicateKeyError({ message: 'other' })).toBe(false);
  });

  test('splitResultFromInvestment maps fields', () => {
    const inv = {
      id: 'inv1',
      get: (k) => (k === 'sequenceNumber' ? 2 : k === 'investmentNumber' ? 'INV-2' : null),
    };
    expect(splitResultFromInvestment(inv, true)).toEqual({
      investmentId: 'inv1',
      sequenceNumber: 2,
      investmentNumber: 'INV-2',
      idempotentReplay: true,
      status: 'replayed',
    });
  });
});
