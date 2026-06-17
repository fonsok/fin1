'use strict';

const mockRows = [
  {
    id: 'ok-1',
    createdAt: new Date('2026-06-01T10:00:00Z'),
    get: (key) => ({
      amount: 100.5,
      balanceBefore: 1000,
      balanceAfter: 1100.5,
      userId: 'u1',
      entryType: 'trading_credit',
      tradeId: 't1',
    }[key]),
  },
  {
    id: 'bad-1',
    createdAt: new Date('2026-06-02T10:00:00Z'),
    get: (key) => ({
      amount: 100.501,
      balanceBefore: 1000,
      balanceAfter: 1100.501,
      userId: 'u2',
      entryType: 'commission_debit',
      tradeId: 't2',
    }[key]),
  },
];

global.Parse = {
  Query: jest.fn().mockImplementation((className) => {
    if (className !== 'AccountStatement') {
      throw new Error(`unexpected query class ${className}`);
    }
    return {
      equalTo: jest.fn().mockReturnThis(),
      descending: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      find: jest.fn(async () => mockRows),
    };
  }),
};

const {
  collectNonCentAlignedFields,
  inspectAccountStatementCentAlignment,
} = require('../accountStatementCentAlignmentInspect');

describe('accountStatementCentAlignmentInspect', () => {
  test('collectNonCentAlignedFields flags sub-cent dust', () => {
    const row = {
      get: (key) => ({ amount: 0.3, balanceBefore: 0, balanceAfter: 0.30000000000000004 }[key]),
    };
    expect(collectNonCentAlignedFields(row)).toEqual([]);
  });

  test('collectNonCentAlignedFields detects non-cent-aligned amount', () => {
    const row = { get: (key) => ({ amount: 12.345 }[key]) };
    expect(collectNonCentAlignedFields(row)).toEqual([{ field: 'amount', value: 12.345 }]);
  });

  test('inspectAccountStatementCentAlignment reports violation rows', async () => {
    const report = await inspectAccountStatementCentAlignment({ limitRows: 100 });

    expect(report.healthy).toBe(false);
    expect(report.examined).toBe(2);
    expect(report.alignedRows).toBe(1);
    expect(report.violationRows).toBe(1);
    expect(report.violations[0].id).toBe('bad-1');
    expect(report.violations[0].fields).toEqual([
      { field: 'amount', value: 100.501 },
      { field: 'balanceAfter', value: 1100.501 },
    ]);
  });
});
