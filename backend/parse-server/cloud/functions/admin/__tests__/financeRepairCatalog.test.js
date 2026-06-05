'use strict';

const { REPAIR_CATALOG, handleGetFinanceRepairCatalog } = require('../financeRepairCatalog');

describe('financeRepairCatalog', () => {
  test('catalog has unique ids', () => {
    const ids = REPAIR_CATALOG.map((e) => e.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('settlement_retry_blocked maps to reconcileStaleSettlementRetryJobs', () => {
    const entry = REPAIR_CATALOG.find((e) => e.id === 'settlement_retry_blocked');
    expect(entry.cloudFunction).toBe('reconcileStaleSettlementRetryJobs');
    expect(entry.defaultParams.dryRun).toBe(true);
  });

  test('filters by issueCode', () => {
    const result = handleGetFinanceRepairCatalog({ params: { issueCode: 'paired_sell_investor_chain' } });
    expect(result.count).toBeGreaterThan(0);
    result.entries.forEach((entry) => {
      expect(
        entry.relatedChecks.includes('paired_sell_investor_chain') || entry.id === 'paired_sell_investor_chain',
      ).toBe(true);
    });
  });
});
