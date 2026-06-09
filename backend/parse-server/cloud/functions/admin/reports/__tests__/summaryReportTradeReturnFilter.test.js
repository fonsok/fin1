'use strict';

const {
  normalizeTradeReturnFilter,
  buildTradeReturnMongoClause,
  buildTradeReturnPercentageExpr,
} = require('../summaryReportTradeReturnFilter');
const { buildTradeLegReturnPercentageMongoExpr } = require('../../../../utils/accountingHelper/legPriceMetricsMongo');
const { normalizeTradeListFilters } = require('../summaryReportFilterHelpers');
const { buildTradeMongoMatch } = require('../summaryReportMongoMatch');

describe('summaryReportTradeReturnFilter', () => {
  test('normalizeTradeReturnFilter parses preset thresholds', () => {
    expect(normalizeTradeReturnFilter({ returnFilter: 'gt:100' })).toEqual({
      returnOp: 'gt',
      returnThreshold: 100,
    });
    expect(normalizeTradeReturnFilter({ returnFilter: 'lt:-10' })).toEqual({
      returnOp: 'lt',
      returnThreshold: -10,
    });
    expect(normalizeTradeReturnFilter({ returnFilter: 'lt:-30' })).toEqual({
      returnOp: 'lt',
      returnThreshold: -30,
    });
  });

  test('normalizeTradeReturnFilter parses custom operator and percent', () => {
    expect(
      normalizeTradeReturnFilter({
        returnFilter: 'custom',
        returnCustomOp: 'gte',
        returnCustomPct: '12,5',
      }),
    ).toEqual({
      returnOp: 'gte',
      returnThreshold: 12.5,
    });
  });

  test('normalizeTradeListFilters ignores invalid return presets', () => {
    expect(
      normalizeTradeListFilters({ returnFilter: 'gt:9999' }).returnOp,
    ).toBeUndefined();
  });

  test('buildTradeMongoMatch adds return percentage expr clause', () => {
    const match = buildTradeMongoMatch({
      returnOp: 'gt',
      returnThreshold: 20,
    });
    const clauses = match.$and || [match];
    const returnClause = clauses.find((c) => c.$expr && c.$expr.$gt);
    expect(returnClause).toBeDefined();
    expect(buildTradeReturnMongoClause('gt', 20)).toEqual(returnClause);
  });

  test('buildTradeReturnPercentageExpr delegates to legPriceMetricsMongo SSOT', () => {
    expect(buildTradeReturnPercentageExpr({})).toEqual(buildTradeLegReturnPercentageMongoExpr({}));
  });
});
