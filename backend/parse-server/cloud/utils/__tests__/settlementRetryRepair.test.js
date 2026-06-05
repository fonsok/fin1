'use strict';

const {
  isRecoverableError,
  isTradeNotFoundError,
} = require('../accountingHelper/settlementRetryRepair');

describe('settlementRetryRepair helpers', () => {
  test('isRecoverableError matches known code-fix patterns', () => {
    expect(isRecoverableError('findExistingStatementEntry is not defined')).toBe(true);
    expect(isRecoverableError('getMirrorTradeForPairedTraderLeg is not a function')).toBe(true);
    expect(isRecoverableError('Cannot read property x of undefined')).toBe(true);
  });

  test('isRecoverableError rejects business failures', () => {
    expect(isRecoverableError('insufficient pool quantity')).toBe(false);
    expect(isRecoverableError('')).toBe(false);
  });

  test('isTradeNotFoundError', () => {
    expect(isTradeNotFoundError('Object not found.')).toBe(true);
    expect(isTradeNotFoundError('trade missing')).toBe(false);
  });
});
