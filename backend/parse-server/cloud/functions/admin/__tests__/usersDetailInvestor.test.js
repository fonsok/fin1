'use strict';

describe('usersDetailInvestor position amount SSOT', () => {
  let mapInvestmentsForAdminDetail;

  const fakeInvestment = (overrides = {}) => ({
    id: overrides.id || 'inv-1',
    get(field) {
      const fields = {
        amount: overrides.amount ?? 1000,
        status: overrides.status ?? 'active',
        reservationStatus: overrides.reservationStatus ?? 'active',
        poolTradingAmount: overrides.poolTradingAmount ?? 997.69,
        profit: overrides.profit ?? 0,
        profitPercentage: overrides.profitPercentage ?? 0,
        traderId: 'trader-1',
        traderName: 'Trader One',
        investmentNumber: 'INV-1',
        currentValue: overrides.currentValue ?? 1000,
        createdAt: new Date('2026-04-20T00:00:00Z'),
      };
      return fields[field];
    },
  });

  beforeEach(() => {
    jest.resetModules();

    class FakeQuery {
      constructor(cls) {
        this.cls = cls;
      }
      equalTo() { return this; }
      containedIn() { return this; }
      exists() { return this; }
      descending() { return this; }
      limit() { return this; }
      async find() { return []; }
      async first() { return null; }
      async get() { throw new Error('not found'); }
      static or(...queries) {
        return queries[0];
      }
    }

    global.Parse = { Query: FakeQuery };

    // eslint-disable-next-line global-require
    mapInvestmentsForAdminDetail = require('../usersDetailInvestor').mapInvestmentsForAdminDetail;
  });

  test('mapInvestmentsForAdminDetail uses poolTradingAmount for active investment', async () => {
    const rows = await mapInvestmentsForAdminDetail([fakeInvestment()], (d) => d?.toISOString?.() ?? null, {});
    expect(rows[0].amount).toBeCloseTo(997.69, 6);
  });

  test('mapInvestmentsForAdminDetail prefers Collection Bill totalBuyCost', async () => {
    const inv = fakeInvestment({
      id: 'inv-completed',
      status: 'completed',
      reservationStatus: 'completed',
      poolTradingAmount: 997.69,
    });
    const rows = await mapInvestmentsForAdminDetail(
      [inv],
      (d) => d?.toISOString?.() ?? null,
      { 'inv-completed': { totalBuyCost: 999.8 } },
    );
    expect(rows[0].amount).toBeCloseTo(999.8, 6);
  });

  test('mapInvestmentsForAdminDetail keeps reserved nominal', async () => {
    const inv = fakeInvestment({
      status: 'reserved',
      reservationStatus: 'reserved',
      poolTradingAmount: 997.69,
    });
    const rows = await mapInvestmentsForAdminDetail([inv], (d) => d?.toISOString?.() ?? null, {});
    expect(rows[0].amount).toBe(1000);
  });
});
