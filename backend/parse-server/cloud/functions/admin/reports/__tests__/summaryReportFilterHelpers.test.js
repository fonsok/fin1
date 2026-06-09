'use strict';

const {
  normalizeInvestmentListFilters,
  normalizeTradeListFilters,
} = require('../summaryReportFilterHelpers');

describe('summaryReportFilterHelpers', () => {
  test('normalizeInvestmentListFilters trims search and validates status', () => {
    expect(
      normalizeInvestmentListFilters({
        search: '  INV-1  ',
        status: 'active',
        returnSign: 'positive',
      }),
    ).toEqual({
      dateFrom: undefined,
      dateTo: undefined,
      investorId: undefined,
      traderId: undefined,
      search: 'INV-1',
      status: 'active',
      returnSign: 'positive',
    });

    expect(
      normalizeInvestmentListFilters({ status: 'invalid', returnSign: 'any' }),
    ).toEqual({
      dateFrom: undefined,
      dateTo: undefined,
      investorId: undefined,
      traderId: undefined,
      search: undefined,
      status: undefined,
      returnSign: undefined,
    });
  });

  test('normalizeTradeListFilters validates trade-specific filters', () => {
    expect(
      normalizeTradeListFilters({
        search: 'AAPL',
        status: 'partial',
        profitSign: 'negative',
        sellProgress: 'full',
        hasPoolInvestors: 'yes',
        returnFilter: 'gt:80',
      }),
    ).toEqual({
      dateFrom: undefined,
      dateTo: undefined,
      traderId: undefined,
      search: 'AAPL',
      status: 'partial',
      profitSign: 'negative',
      sellProgress: 'full',
      hasPoolInvestors: 'yes',
      returnOp: 'gt',
      returnThreshold: 80,
    });

    expect(
      normalizeTradeListFilters({
        profitSign: 'any',
        sellProgress: 'bogus',
        hasPoolInvestors: 'maybe',
      }),
    ).toEqual({
      dateFrom: undefined,
      dateTo: undefined,
      traderId: undefined,
      search: undefined,
      status: undefined,
      profitSign: undefined,
      sellProgress: undefined,
      hasPoolInvestors: undefined,
      returnOp: undefined,
      returnThreshold: undefined,
    });
  });
});
