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

  test('trade pool filter matches participation flag or paired execution', () => {
    const yes = buildTradeMongoMatch({ hasPoolInvestors: 'yes' });
    const yesClauses = yes.$and || [yes];
    const poolClause = yesClauses.find((c) => c.$or && c.$or.some((o) => o.hasPoolParticipation === true));
    expect(poolClause).toBeDefined();

    const no = buildTradeMongoMatch({ hasPoolInvestors: 'no' });
    const noClauses = no.$and || [no];
    const noPoolClause = noClauses.find((c) => c.$and);
    expect(noPoolClause).toBeDefined();
  });

  test('trade search uses indexed tradeNumber for numeric query', () => {
    const match = buildTradeMongoMatch({ search: '42' });
    const clauses = match.$and || [match];
    const searchClause = clauses.find((c) => c.$or && c.$or.some((o) => o.tradeNumber === 42));
    expect(searchClause).toBeDefined();
  });
});
