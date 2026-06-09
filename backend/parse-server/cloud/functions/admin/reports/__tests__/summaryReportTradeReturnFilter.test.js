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

  test('buildTradeMongoMatch adds return percentage clause with persisted snapshot fallback', () => {
    const match = buildTradeMongoMatch({
      returnOp: 'gt',
      returnThreshold: 20,
    });
    const clauses = match.$and || [match];
    const returnClause = clauses.find((c) => c.$or);
    expect(returnClause).toBeDefined();
    expect(buildTradeReturnMongoClause('gt', 20)).toEqual(returnClause);
    expect(returnClause.$or[0]['legEconomicsSnapshot.returnPercentage']).toEqual({ gt: 20 });
    expect(returnClause.$or[1].$and[1].$expr.$gt).toBeDefined();
  });

  test('buildTradeReturnPercentageExpr delegates to legPriceMetricsMongo SSOT', () => {
    expect(buildTradeReturnPercentageExpr({})).toEqual(buildTradeLegReturnPercentageMongoExpr({}));
  });
});
