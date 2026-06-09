'use strict';

const {
  appendTraderIdsToSearchClause,
  buildTradeSearchBlob,
} = require('../../../../utils/adminListSearch');

describe('summaryReport trader search', () => {
  test('buildTradeSearchBlob includes traderName', () => {
    const blob = buildTradeSearchBlob({
      get: (k) => ({
        tradeNumber: 7,
        symbol: 'DAX',
        buyOrder: { symbol: 'DAX' },
        traderId: 'trader-1',
        traderName: 'Max Mustermann',
      })[k],
    });
    expect(blob).toContain('max mustermann');
  });

  test('appendTraderIdsToSearchClause merges traderId $in into $or', () => {
    const merged = appendTraderIdsToSearchClause(
      { $text: { $search: 'max' } },
      ['trader-1', 'user:max@test.de'],
    );
    expect(merged.$or).toEqual(
      expect.arrayContaining([
        { $text: { $search: 'max' } },
        { traderId: { $in: ['trader-1', 'user:max@test.de'] } },
      ]),
    );
  });
});
