'use strict';

const { syncPoolMirrorInvestorCount } = require('../summaryReportTradePoolEnrichment');

describe('syncPoolMirrorInvestorCount', () => {
  test('raises snap count from participations when snap is 0', () => {
    const poolMirrorTrade = { tradeId: 'pool-1', poolInvestorCount: 0 };
    const poolParticipations = [{ investorId: 'inv-1', investorName: 'Investor One' }];

    expect(syncPoolMirrorInvestorCount(poolMirrorTrade, poolParticipations)).toEqual({
      tradeId: 'pool-1',
      poolInvestorCount: 1,
    });
  });

  test('keeps higher snap count when already correct', () => {
    const poolMirrorTrade = { tradeId: 'pool-1', poolInvestorCount: 2 };
    const poolParticipations = [{ investorId: 'inv-1' }];

    expect(syncPoolMirrorInvestorCount(poolMirrorTrade, poolParticipations)).toBe(poolMirrorTrade);
  });

  test('counts unique investorIds', () => {
    const poolMirrorTrade = { tradeId: 'pool-1', poolInvestorCount: 0 };
    const poolParticipations = [
      { investorId: 'inv-1' },
      { investorId: 'inv-1' },
      { investorId: 'inv-2' },
    ];

    expect(syncPoolMirrorInvestorCount(poolMirrorTrade, poolParticipations).poolInvestorCount).toBe(2);
  });

  test('returns nullish pool mirror unchanged', () => {
    expect(syncPoolMirrorInvestorCount(null, [])).toBeNull();
    expect(syncPoolMirrorInvestorCount(undefined, [])).toBeUndefined();
  });
});
