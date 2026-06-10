'use strict';

const {
  buildTraderStatementCustomerDisplay,
  customerDisplayFromPersistedBelegMetadata,
  isCustomerDisplaySnapshot,
} = require('../traderStatementCustomerDisplay');

function makeTrade(attrs) {
  return {
    get: (key) => attrs[key],
  };
}

describe('traderStatementCustomerDisplay', () => {
  test('buildTraderStatementCustomerDisplay prefers partial sell order quantity', () => {
    const trade = makeTrade({
      wkn: 'VO47OXA',
      symbol: 'VO47OXA',
      securityType: 'PUT',
      quantity: 900,
      buyOrder: { wkn: 'VO47OXA', quantity: 900 },
      sellOrder: {},
      sellOrders: [],
    });
    const display = buildTraderStatementCustomerDisplay({
      trade,
      order: { quantity: 300, executedQuantity: 0 },
      orderLike: { quantity: 300, executedQuantity: 0 },
      executionType: 'sell',
      metadata: {
        quantity: 900,
        partialSell: { orderQuantity: 300 },
      },
    });
    expect(display.quantity).toBe('300');
    expect(isCustomerDisplaySnapshot(display)).toBe(true);
    expect(display.statementTitle).toContain('VO47OXA');
  });

  test('customerDisplayFromPersistedBelegMetadata rebuilds from TSC metadata', () => {
    const display = customerDisplayFromPersistedBelegMetadata({
      executionType: 'sell',
      quantity: 1000,
      partialSell: { orderQuantity: 300 },
      instrumentLine: 'VO47OXA - PUT - DAX',
      wkn: 'VO47OXA',
    }, 'sell');
    expect(display.quantity).toBe('300');
    expect(display.wknOrIsin).toBe('VO47OXA');
    expect(display.securitiesDirection).toBe('PUT');
    expect(display.underlyingAsset).toBe('DAX');
  });
});
