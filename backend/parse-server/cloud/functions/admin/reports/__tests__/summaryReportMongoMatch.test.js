'use strict';

const {
  buildInvestmentMongoMatch,
  buildTradeMongoMatch,
} = require('../summaryReportMongoMatch');

describe('summaryReportMongoMatch', () => {
  test('investment returnSign uses currentValue vs amount expr', () => {
    const match = buildInvestmentMongoMatch({
      returnSign: 'positive',
      status: 'active',
    });
    expect(match.$and).toBeDefined();
    const exprClause = match.$and.find((c) => c.$expr);
    expect(exprClause.$expr.$gt).toHaveLength(2);
  });

  test('trade pool filter uses denormalized hasPoolParticipation', () => {
    const yes = buildTradeMongoMatch({ hasPoolInvestors: 'yes' });
    expect(yes.hasPoolParticipation).toBe(true);

    const no = buildTradeMongoMatch({ hasPoolInvestors: 'no' });
    expect(no.hasPoolParticipation).toEqual({ $ne: true });
  });

  test('trade search uses indexed tradeNumber for numeric query', () => {
    const match = buildTradeMongoMatch({ search: '42' });
    const clauses = match.$and || [match];
    const searchClause = clauses.find((c) => c.$or && c.$or.some((o) => o.tradeNumber === 42));
    expect(searchClause).toBeDefined();
  });
});
