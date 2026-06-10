'use strict';

const {
  deduplicatedTraderCashLegs,
  traderCashLegDedupKey,
} = require('../cashLegDedup');

function mockStmt(id, entryType, amount, extra = {}) {
  return {
    id,
    get: (key) => ({
      entryType,
      amount,
      tradeId: extra.tradeId || 'trade-1',
      tradeNumber: extra.tradeNumber ?? 1,
      referenceDocumentId: extra.referenceDocumentId || null,
      referenceDocumentNumber: extra.referenceDocumentNumber || null,
      createdAt: extra.createdAt || new Date(),
    }[key]),
  };
}

describe('cashLegDedup', () => {
  test('partial sells keep distinct TSC legs on same trade number', () => {
    const legs = [
      mockStmt('s1', 'trade_sell', 1500, { referenceDocumentNumber: 'TSC-2026-0000128' }),
      mockStmt('s2', 'trade_sell', 900, { referenceDocumentNumber: 'TSC-2026-0000129' }),
    ];
    const deduped = deduplicatedTraderCashLegs(legs);
    expect(deduped).toHaveLength(2);
    expect(traderCashLegDedupKey(legs[0])).toBe('sell:beleg:TSC-2026-0000128');
    expect(traderCashLegDedupKey(legs[1])).toBe('sell:beleg:TSC-2026-0000129');
  });

  test('INV duplicate is dropped when TSC exists for same trade and amount', () => {
    const legs = [
      mockStmt('inv', 'trade_sell', 4000, { referenceDocumentNumber: 'ABCDEFG-INV-001' }),
      mockStmt('tsc', 'trade_sell', 4000, { referenceDocumentNumber: 'TSC-2026-0000001' }),
    ];
    const deduped = deduplicatedTraderCashLegs(legs);
    expect(deduped).toHaveLength(1);
    expect(deduped[0].id).toBe('tsc');
  });

  test('trade_buy still dedupes by trade number', () => {
    const legs = [
      mockStmt('b1', 'trade_buy', -1000, { tradeId: 'a', referenceDocumentNumber: 'TBC-1' }),
      mockStmt('b2', 'trade_buy', -1000, { tradeId: 'b', referenceDocumentNumber: 'TBC-2' }),
    ];
    const deduped = deduplicatedTraderCashLegs(legs);
    expect(deduped).toHaveLength(1);
  });
});
