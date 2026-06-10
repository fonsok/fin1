'use strict';

const {
  buildInvestmentSearchBlob,
  buildTradeSearchBlob,
  buildAdminListSearchMatchClause,
  buildAdminListSearchPrefixClause,
  normalizeAdminSearchTerm,
  isMongoTextIndexError,
} = require('../adminListSearch');

describe('adminListSearch', () => {
  test('normalizeAdminSearchTerm caps length', () => {
    expect(normalizeAdminSearchTerm('  foo  ')).toBe('foo');
    expect(normalizeAdminSearchTerm('x'.repeat(100)).length).toBe(80);
  });

  test('buildInvestmentSearchBlob lowercases combined fields', () => {
    const blob = buildInvestmentSearchBlob({
      get: (k) => ({
        investmentNumber: 'INV-2026-001',
        investorName: 'Max M.',
        traderName: 'Trader T.',
      })[k],
    });
    expect(blob).toContain('inv-2026-001');
    expect(blob).toContain('max m.');
  });

  test('buildTradeSearchBlob includes trade number, symbol and traderName', () => {
    const blob = buildTradeSearchBlob({
      get: (k) => ({
        tradeNumber: 42,
        symbol: 'AAPL',
        buyOrder: { symbol: 'AAPL' },
        traderId: 't1',
        traderName: 'Trader T.',
      })[k],
    });
    expect(blob).toContain('42');
    expect(blob).toContain('aapl');
    expect(blob).toContain('trader t.');
  });

  test('buildAdminListSearchMatchClause uses tradeNumber for numeric', () => {
    const clause = buildAdminListSearchMatchClause('Trade', '42');
    expect(clause.$or).toEqual(
      expect.arrayContaining([{ tradeNumber: 42 }]),
    );
  });

  test('buildAdminListSearchMatchClause uses $text for word search', () => {
    const clause = buildAdminListSearchMatchClause('Investment', 'fischer');
    expect(clause.$text).toEqual({ $search: 'fischer' });
  });

  test('prefix fallback uses adminSearchBlob range', () => {
    const clause = buildAdminListSearchPrefixClause('Trade', 'aapl');
    const parts = clause.$or || [clause];
    const blobClause = parts.find((p) => p.adminSearchBlob);
    expect(blobClause.adminSearchBlob.$gte).toBe('aapl');
    expect(blobClause.adminSearchBlob.$lt).toContain('aapl');
  });

  test('isMongoTextIndexError detects text index failures', () => {
    expect(isMongoTextIndexError(new Error('text index required'))).toBe(true);
    expect(isMongoTextIndexError(new Error('timeout'))).toBe(false);
  });
});
