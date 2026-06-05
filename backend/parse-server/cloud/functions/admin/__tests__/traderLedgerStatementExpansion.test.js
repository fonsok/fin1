'use strict';

const {
  expandSingleTradeLedgerEvents,
  computeBuyOnlyTradingFees,
} = require('../traderLedgerStatementExpansion');

function mockTrade(buyAmount, sellAmount = 0) {
  return {
    get: (key) => {
      if (key === 'buyOrder') return { totalAmount: buyAmount };
      if (key === 'sellOrders') return sellAmount > 0 ? [{ totalAmount: sellAmount }] : [];
      if (key === 'sellOrder') return sellAmount > 0 ? { totalAmount: sellAmount } : null;
      if (key === 'symbol') return 'VO5G3MN';
      if (key === 'tradeNumber') return 1;
      return null;
    },
  };
}

function mockEvent(entryType, amount, at, extra = {}) {
  return {
    objectId: extra.objectId || `${entryType}-${at.getTime()}`,
    entryType,
    amount,
    at,
    tradeId: 'trade1',
    tradeNumber: 1,
    description: entryType,
    referenceDocumentId: null,
    referenceDocumentNumber: null,
    source: 'backend',
    _row: null,
  };
}

describe('traderLedgerStatementExpansion', () => {
  test('computeBuyOnlyTradingFees returns positive amount for buy order', () => {
    const fees = computeBuyOnlyTradingFees(mockTrade(3000));
    expect(fees.totalFees).toBeGreaterThan(0);
  });

  test('inserts buy trading_fees after trade_buy when only aggregate fee exists at sell', () => {
    const tBuy = new Date('2026-05-18T10:41:00Z');
    const tSell = new Date('2026-05-18T10:43:00Z');
    const trade = mockTrade(3000, 4000);
    const buyFees = computeBuyOnlyTradingFees(trade);

    const events = expandSingleTradeLedgerEvents([
      mockEvent('trade_buy', -3000, tBuy),
      mockEvent('trade_sell', 4000, tSell),
      mockEvent('trading_fees', -(buyFees.totalFees + 10), tSell, { objectId: 'fee-total' }),
      mockEvent('commission_credit', 32, new Date(tSell.getTime() + 1000)),
    ], trade);

    const types = events.map((e) => e.entryType);
    const feeIndices = types
      .map((t, i) => (t === 'trading_fees' ? i : -1))
      .filter((i) => i >= 0);
    expect(feeIndices.length).toBeGreaterThanOrEqual(2);
    const buyIdx = types.indexOf('trade_buy');
    const firstFeeIdx = feeIndices[0];
    expect(firstFeeIdx).toBe(buyIdx + 1);
    expect(events[firstFeeIdx].description).toContain('Kauf');
  });
});
