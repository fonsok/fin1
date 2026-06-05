'use strict';

const { mergeInvestorFeeConfig } = require('../feeConfigSnapshot');

describe('mergeInvestorFeeConfig', () => {
  test('prefers investment feeConfigSnapshot over live financial', () => {
    const investment = {
      get: (k) => (k === 'feeConfigSnapshot'
        ? { orderFeeMin: 5, foreignCosts: 2.5, exchangeFeeMin: 0.5 }
        : null),
    };
    const trade = { get: () => ({}) };
    const live = { orderFeeMin: 5, foreignCosts: 99, exchangeFeeMin: 0.5 };
    const out = mergeInvestorFeeConfig(investment, trade, live);
    expect(out.foreignCosts).toBe(2.5);
  });

  test('trade feeConfig overrides snapshot keys', () => {
    const investment = {
      get: (k) => (k === 'feeConfigSnapshot' ? { foreignCosts: 2.5 } : null),
    };
    const trade = { get: () => ({ foreignCosts: 9.99 }) };
    const out = mergeInvestorFeeConfig(investment, trade, { foreignCosts: 1 });
    expect(out.foreignCosts).toBe(9.99);
  });

  test('without snapshot uses live financial + trade', () => {
    const investment = { get: () => null };
    const trade = { get: () => ({ foreignCosts: 3 }) };
    const out = mergeInvestorFeeConfig(investment, trade, { foreignCosts: 2.5, orderFeeMin: 5 });
    expect(out.foreignCosts).toBe(3);
    expect(out.orderFeeMin).toBe(5);
  });
});
