'use strict';

const {
  splitCommissionFromGrossProfit,
  resolveCommissionPartsFromBillMetadata,
} = require('../commissionSplit');

describe('commissionSplit', () => {
  test('splitCommissionFromGrossProfit splits trader and app shares', () => {
    const result = splitCommissionFromGrossProfit(1000, { traderRate: 0.1, appRate: 0.05 });
    expect(result.traderCommission).toBe(100);
    expect(result.appCommission).toBe(50);
    expect(result.commission).toBe(150);
    expect(result.netProfit).toBe(850);
  });

  test('zero or negative gross profit yields no commission', () => {
    expect(splitCommissionFromGrossProfit(0, { traderRate: 0.1, appRate: 0.05 }).commission).toBe(0);
    expect(splitCommissionFromGrossProfit(-10, { traderRate: 0.1, appRate: 0.05 }).commission).toBe(0);
  });

  test('resolveCommissionPartsFromBillMetadata reads persisted split', () => {
    const parts = resolveCommissionPartsFromBillMetadata({
      commission: 150,
      traderCommission: 100,
      appCommission: 50,
    });
    expect(parts).toEqual({ commission: 150, traderCommission: 100, appCommission: 50 });
  });

  test('legacy metadata treats full commission as trader share', () => {
    const parts = resolveCommissionPartsFromBillMetadata({ commission: 80 });
    expect(parts).toEqual({ commission: 80, traderCommission: 80, appCommission: 0 });
  });
});
