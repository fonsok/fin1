'use strict';

const { preparePairedBuyLegExecutedFields } = require('../pairedBuyOrchestration');

function makeOrder(fields) {
  const attrs = { ...fields };
  return {
    get(key) {
      return attrs[key];
    },
    set(key, value) {
      attrs[key] = value;
    },
  };
}

describe('pairedBuyOrchestration', () => {
  test('preparePairedBuyLegExecutedFields retries executed without tradeId', () => {
    const order = makeOrder({
      side: 'buy',
      status: 'executed',
      tradeId: null,
      quantity: 100,
      price: 2,
    });
    const prepared = preparePairedBuyLegExecutedFields(order);
    expect(prepared).toBe(order);
    expect(order.get('status')).toBe('executed');
    expect(order.get('grossAmount')).toBe(200);
  });

  test('preparePairedBuyLegExecutedFields skips when trade already linked', () => {
    const order = makeOrder({
      side: 'buy',
      status: 'executed',
      tradeId: 'trade-1',
      quantity: 1,
      price: 1,
    });
    expect(preparePairedBuyLegExecutedFields(order)).toBeNull();
  });
});
