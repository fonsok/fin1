'use strict';

const { auditUserCashBalanceDriftIfNeeded } = require('../customerClosingBalance');

describe('auditUserCashBalanceDriftIfNeeded', () => {
  test('no-op when balances match within tolerance', () => {
    expect(() => auditUserCashBalanceDriftIfNeeded('u1', 9522.31, 9522.31)).not.toThrow();
  });

  test('no-op when drift is within 2 cents', () => {
    expect(() => auditUserCashBalanceDriftIfNeeded('u1', 9522.31, 9522.32)).not.toThrow();
  });
});
