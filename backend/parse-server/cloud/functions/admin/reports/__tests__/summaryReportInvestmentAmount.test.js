'use strict';

describe('summaryReportInvestmentRows resolveInvestmentDisplayAmount', () => {
  let resolveInvestmentDisplayAmount;
  let mapInvestmentRow;

  const fakeInvestment = (overrides = {}) => ({
    id: overrides.id || 'inv-1',
    _fields: {
      amount: overrides.amount ?? 1000,
      currentValue: overrides.currentValue ?? 1000,
      poolTradingAmount: overrides.poolTradingAmount ?? null,
      status: overrides.status ?? 'active',
      reservationStatus: overrides.reservationStatus ?? null,
      investorId: 'investor-1',
      investorName: 'Investor One',
      traderId: 'trader-1',
      traderName: 'Trader One',
      investmentNumber: 'INV-1',
      createdAt: new Date('2026-04-20T00:00:00Z'),
    },
    get(field) {
      return this._fields[field];
    },
  });

  beforeEach(() => {
    jest.resetModules();
    global.Parse = {
      Cloud: { define() {} },
      Query: class FakeQuery {
        containedIn() { return this; }
        limit() { return this; }
        async find() { return []; }
      },
    };
    // eslint-disable-next-line global-require
    const mod = require('../summary');
    resolveInvestmentDisplayAmount = mod.__test__.resolveInvestmentDisplayAmount;
    mapInvestmentRow = mod.__test__.mapInvestmentRow;
  });

  test('reserved status returns nominal amount', () => {
    const inv = fakeInvestment({ status: 'reserved', amount: 1000, poolTradingAmount: 997.69 });
    expect(resolveInvestmentDisplayAmount(inv)).toBe(1000);
  });

  test('reserved reservationStatus returns nominal amount even when status differs', () => {
    const inv = fakeInvestment({
      status: 'active',
      reservationStatus: 'reserved',
      amount: 1000,
      poolTradingAmount: 997.69,
    });
    expect(resolveInvestmentDisplayAmount(inv)).toBe(1000);
  });

  test('active investment returns poolTradingAmount when present', () => {
    const inv = fakeInvestment({
      status: 'active',
      reservationStatus: 'active',
      amount: 1000,
      poolTradingAmount: 997.69,
    });
    expect(resolveInvestmentDisplayAmount(inv)).toBeCloseTo(997.69, 6);
  });

  test('completed investment returns poolTradingAmount when present', () => {
    const inv = fakeInvestment({
      status: 'completed',
      reservationStatus: 'completed',
      amount: 1000,
      poolTradingAmount: 999.8,
    });
    expect(resolveInvestmentDisplayAmount(inv)).toBeCloseTo(999.8, 6);
  });

  test('falls back to nominal when poolTradingAmount missing on active investment', () => {
    const inv = fakeInvestment({
      status: 'active',
      reservationStatus: 'active',
      amount: 1000,
      poolTradingAmount: null,
    });
    expect(resolveInvestmentDisplayAmount(inv)).toBe(1000);
  });

  test('mapInvestmentRow exposes poolTradingAmount for active investment', () => {
    const inv = fakeInvestment({
      status: 'active',
      reservationStatus: 'active',
      amount: 1000,
      currentValue: 1100,
      poolTradingAmount: 997.69,
    });
    const row = mapInvestmentRow(inv, 0.1, {});
    expect(row.amount).toBeCloseTo(997.69, 6);
    expect(row.grossProfit).toBeCloseTo(1100 - 997.69, 6);
  });

  test('mapInvestmentRow uses Collection Bill totalBuyCost when canonical metrics provided', () => {
    const inv = fakeInvestment({
      status: 'completed',
      reservationStatus: 'completed',
      amount: 1000,
      currentValue: 1100,
      poolTradingAmount: 997.69,
    });
    const row = mapInvestmentRow(inv, 0.1, {
      [inv.id]: { totalBuyCost: 999.8, returnPercentage: 5 },
    });
    expect(row.amount).toBeCloseTo(999.8, 6);
    expect(row.returnPercentage).toBeCloseTo(5, 6);
  });
});
