'use strict';

const {
  readAggregateGroupKey,
  readAggregateGroupPayload,
} = require('../summaryReportAggregateKey');

describe('summaryReportAggregateKey', () => {
  test('readAggregateGroupKey prefers Parse objectId over _id', () => {
    expect(readAggregateGroupKey({ objectId: 'pool-1', count: 2 })).toBe('pool-1');
    expect(readAggregateGroupKey({ _id: 'pool-2', count: 1 })).toBe('pool-2');
    expect(readAggregateGroupKey({ objectId: 'pool-3', _id: 'ignored' })).toBe('pool-3');
    expect(readAggregateGroupKey(null)).toBe('');
  });

  test('readAggregateGroupPayload supports compound group keys', () => {
    const compound = { account: 'CLIENT_LIABILITY', side: 'credit' };
    expect(readAggregateGroupPayload({ objectId: compound })).toEqual(compound);
    expect(readAggregateGroupPayload({ _id: compound })).toEqual(compound);
    expect(readAggregateGroupPayload({ objectId: compound, totalAmount: 10 })).toEqual(compound);
  });
});
