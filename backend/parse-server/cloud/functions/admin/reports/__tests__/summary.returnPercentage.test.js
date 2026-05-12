'use strict';

// Unit tests for admin summary report ROI2 single-source-of-truth behavior.
// See: Documentation/RETURN_CALCULATION_SCHEMAS.md
//      Documentation/ADR-006-Server-Owned-Return-Percentage-Contract.md

describe('admin summary report returnPercentage (ROI2, SSOT)', () => {
  let mapInvestmentRow;
  let loadCanonicalReturnByInvestmentId;

  const fakeInvestment = (overrides = {}) => ({
    id: overrides.id || 'inv-1',
    _fields: {
      amount: overrides.amount ?? 0,
      currentValue: overrides.currentValue ?? null,
      investorId: overrides.investorId || 'investor-1',
      investorName: overrides.investorName || 'Investor One',
      traderId: overrides.traderId || 'trader-1',
      traderName: overrides.traderName || 'Trader One',
      status: overrides.status || 'closed',
      investmentNumber: overrides.investmentNumber || 'INV-1',
      createdAt: overrides.createdAt || new Date('2026-04-20T00:00:00Z'),
    },
    get(field) {
      return this._fields[field];
    },
  });

  beforeEach(() => {
    jest.resetModules();
    // Register a minimal global Parse for module load (not actually used in unit tests here).
    global.Parse = {
      Cloud: { define() {} },
      Query: class FakeQuery {
        constructor() { this.filters = []; }
        containedIn() { return this; }
        limit() { return this; }
        async find() { return []; }
      },
    };
    // eslint-disable-next-line global-require
    const mod = require('../summary');
    mapInvestmentRow = mod.__test__.mapInvestmentRow;
    loadCanonicalReturnByInvestmentId = mod.__test__.loadCanonicalReturnByInvestmentId;
  });

  test('uses canonical returnPercentage from CollectionBill when provided', () => {
    const commissionRate = 0.1;
    const inv = fakeInvestment({ id: 'inv-1', amount: 200, currentValue: 220 });
    // grossProfit = 20, commission = 2, netProfit = 18 ⇒ ROI2 = 9.00 %
    // But canonical value (from CollectionBill) is 8.50 % — we must prefer it.
    const canonical = { 'inv-1': 8.5 };
    const row = mapInvestmentRow(inv, commissionRate, canonical);
    expect(row.returnPercentage).toBeCloseTo(8.5, 6);
    expect(row.grossProfit).toBeCloseTo(20, 6);
    expect(row.commission).toBeCloseTo(2, 6);
  });

  test('falls back to ROI2 formula ((gross − commission) / amount × 100) when no canonical value', () => {
    const commissionRate = 0.1;
    const inv = fakeInvestment({ id: 'inv-2', amount: 200, currentValue: 220 });
    // grossProfit = 20, commission = 2, netProfit = 18 ⇒ ROI2 = 9.00 %
    const row = mapInvestmentRow(inv, commissionRate, {});
    expect(row.returnPercentage).toBeCloseTo(9.0, 6);
  });

  test('negative gross profit ⇒ commission is 0, ROI2 == ROI1', () => {
    const commissionRate = 0.1;
    const inv = fakeInvestment({ id: 'inv-3', amount: 100, currentValue: 90 });
    // grossProfit = −10, commission = 0, netProfit = −10 ⇒ ROI2 = −10 %
    const row = mapInvestmentRow(inv, commissionRate);
    expect(row.returnPercentage).toBeCloseTo(-10, 6);
    expect(row.commission).toBe(0);
  });

  test('zero amount ⇒ returnPercentage is 0 (avoid div-by-zero)', () => {
    const row = mapInvestmentRow(fakeInvestment({ amount: 0, currentValue: 0 }), 0.1);
    expect(row.returnPercentage).toBe(0);
  });

  test('loadCanonicalReturnByInvestmentId weights by buyLeg invested amount', async () => {
    // Build fake documents and a Parse.Query stub that returns them.
    const docs = [
      // inv-1: two bills; weighted average of 10% (invested 100) and 20% (invested 300)
      // = (10*100 + 20*300) / (100+300) = 7000/400 = 17.5%
      {
        get(field) {
          if (field === 'metadata') {
            return { returnPercentage: 10, buyLeg: { amount: 90, fees: { totalFees: 10 } } };
          }
          if (field === 'investmentId') return 'inv-1';
          return undefined;
        },
      },
      {
        get(field) {
          if (field === 'metadata') {
            return { returnPercentage: 20, buyLeg: { amount: 280, fees: { totalFees: 20 } } };
          }
          if (field === 'investmentId') return 'inv-1';
          return undefined;
        },
      },
      // inv-2: a legacy bill with no buyLeg invested amount ⇒ straight average fallback
      {
        get(field) {
          if (field === 'metadata') return { returnPercentage: 5 };
          if (field === 'investmentId') return 'inv-2';
          return undefined;
        },
      },
    ];

    // Override Parse.Query to return our docs
    global.Parse.Query = class FakeQuery {
      constructor() { this.filters = []; }
      containedIn() { return this; }
      limit() { return this; }
      async find() { return docs; }
    };

    // Reload module so it picks up the new stub
    jest.resetModules();
    // eslint-disable-next-line global-require
    const mod = require('../summary');
    const load = mod.__test__.loadCanonicalReturnByInvestmentId;

    const map = await load(['inv-1', 'inv-2']);
    expect(map['inv-1']).toBeCloseTo(17.5, 6);
    expect(map['inv-2']).toBeCloseTo(5.0, 6);
  });
});
