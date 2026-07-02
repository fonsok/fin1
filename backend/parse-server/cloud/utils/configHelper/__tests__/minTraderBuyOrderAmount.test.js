'use strict';

const {
  normalizeMinTraderBuyOrderAmount,
  assertTraderBuyOrderMeetsMinimum,
} = require('../minTraderBuyOrderAmount');

describe('minTraderBuyOrderAmount', () => {
  test('normalizeMinTraderBuyOrderAmount defaults to 300', () => {
    expect(normalizeMinTraderBuyOrderAmount(undefined)).toBe(300);
    expect(normalizeMinTraderBuyOrderAmount(null)).toBe(300);
  });

  test('normalizeMinTraderBuyOrderAmount allows 0 to disable', () => {
    expect(normalizeMinTraderBuyOrderAmount(0)).toBe(0);
  });

  test('assertTraderBuyOrderMeetsMinimum skips when min is 0', () => {
    expect(() => assertTraderBuyOrderMeetsMinimum(10, 0)).not.toThrow();
  });

  test('assertTraderBuyOrderMeetsMinimum rejects below minimum', () => {
    global.Parse = {
      Error: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
        static get OPERATION_FORBIDDEN() { return 119; }
      },
    };
    expect(() => assertTraderBuyOrderMeetsMinimum(299.99, 300)).toThrow(/Mindest-Kaufbetrag/i);
    expect(() => assertTraderBuyOrderMeetsMinimum(300, 300)).not.toThrow();
  });
});
