'use strict';

const {
  buildExcludePoolMirrorLegMongoClause,
  buildHasPoolInvestorsMongoClause,
} = require('../summaryReportTradeListVisibility');
const { buildTradeMongoMatch } = require('../summaryReportMongoMatch');

describe('summaryReportTradeListVisibility', () => {
  test('excludes MIRROR_POOL and mirror buyOrder flag', () => {
    const clause = buildExcludePoolMirrorLegMongoClause();
    expect(clause.$nor).toEqual(
      expect.arrayContaining([
        { buyLegType: 'MIRROR_POOL' },
        { 'buyOrder.isMirrorPoolOrder': true },
      ]),
    );
  });

  test('hasPoolInvestors yes matches flag or paired trader leg', () => {
    const clause = buildHasPoolInvestorsMongoClause('yes');
    expect(clause.$or).toHaveLength(2);
    expect(clause.$or[0]).toEqual({ hasPoolParticipation: true });
    expect(clause.$or[1].pairExecutionId).toBeDefined();
  });

  test('buildTradeMongoMatch always includes mirror exclusion', () => {
    const match = buildTradeMongoMatch({});
    const clauses = match.$and || [match];
    const hasNor = clauses.some((c) => c.$nor && c.$nor.some((n) => n.buyLegType === 'MIRROR_POOL'));
    expect(hasNor).toBe(true);
  });

  test('legacy standalone trade still matches list filter', () => {
    const match = buildTradeMongoMatch({});
    const legacy = {
      buyLegType: undefined,
      buyOrder: { totalAmount: 100 },
    };
    const mirror = {
      buyLegType: 'MIRROR_POOL',
      buyOrder: { totalAmount: 500, isMirrorPoolOrder: true },
    };
    const trader = {
      buyLegType: 'TRADER',
      pairExecutionId: 'pair-1',
      buyOrder: { totalAmount: 200 },
    };

    const matches = (doc) => {
      const clauses = match.$and || [match];
      return clauses.every((clause) => {
        if (clause.$nor) {
          return !clause.$nor.some((n) => Object.keys(n).every((k) => doc[k] === n[k]));
        }
        return true;
      });
    };

    expect(matches(legacy)).toBe(true);
    expect(matches(trader)).toBe(true);
    expect(matches(mirror)).toBe(false);
  });
});
