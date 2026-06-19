'use strict';

const {
  bookedTotalBuyCostFromMetadata,
  resolveInvestmentDisplayAmountFromFields,
  resolveInvestmentPositionAmountFromFields,
  resolveInvestmentDisplayAmount,
} = require('../investmentDisplayAmount');
const { investmentAggPipeline } = require('../../functions/admin/reports/summaryReportAggPipelines');

describe('investmentDisplayAmount SSOT', () => {
  test('bookedTotalBuyCostFromMetadata prefers totalBuyCost', () => {
    expect(bookedTotalBuyCostFromMetadata({ totalBuyCost: 999.8, poolTradingAmount: 997 })).toBeCloseTo(
      999.8,
      6,
    );
  });

  test('bookedTotalBuyCostFromMetadata derives from nominal minus residual', () => {
    expect(
      bookedTotalBuyCostFromMetadata({ investmentNominal: 1000, residualAmount: 2.31 }),
    ).toBeCloseTo(997.69, 6);
  });

  test('reserved status returns nominal amount', () => {
    expect(
      resolveInvestmentDisplayAmountFromFields({
        amount: 1000,
        status: 'reserved',
        poolTradingAmount: 997.69,
      }),
    ).toBe(1000);
  });

  test('reserved reservationStatus returns nominal even when status differs', () => {
    expect(
      resolveInvestmentDisplayAmountFromFields({
        amount: 1000,
        status: 'active',
        reservationStatus: 'reserved',
        poolTradingAmount: 997.69,
      }),
    ).toBe(1000);
  });

  test('active investment returns poolTradingAmount when present', () => {
    expect(
      resolveInvestmentDisplayAmountFromFields({
        amount: 1000,
        status: 'active',
        reservationStatus: 'active',
        poolTradingAmount: 997.69,
      }),
    ).toBeCloseTo(997.69, 6);
  });

  test('falls back to nominal when poolTradingAmount missing', () => {
    expect(
      resolveInvestmentDisplayAmountFromFields({
        amount: 1000,
        status: 'completed',
        reservationStatus: 'completed',
        poolTradingAmount: null,
      }),
    ).toBe(1000);
  });

  test('completed investment prefers Collection Bill totalBuyCost over poolTradingAmount', () => {
    expect(
      resolveInvestmentPositionAmountFromFields({
        amount: 1000,
        status: 'completed',
        reservationStatus: 'completed',
        poolTradingAmount: 997.69,
        canonicalTotalBuyCost: 999.8,
      }),
    ).toBeCloseTo(999.8, 6);
  });

  test('Parse object wrapper matches field helper', () => {
    const inv = {
      get(field) {
        const fields = {
          amount: 1000,
          status: 'active',
          reservationStatus: 'active',
          poolTradingAmount: 999.8,
        };
        return fields[field];
      },
    };
    expect(resolveInvestmentDisplayAmount(inv)).toBeCloseTo(999.8, 6);
  });
});

describe('investmentAggPipeline overview KPI', () => {
  test('includes Collection Bill $lookup and position amount fields', () => {
    const stages = investmentAggPipeline({});
    expect(stages[0]).toEqual({ $lookup: expect.objectContaining({ from: 'Document', as: 'collectionBills' }) });
    const addFields = stages.filter((s) => s.$addFields);
    expect(addFields.some((s) => Object.prototype.hasOwnProperty.call(s.$addFields, 'canonicalTotalBuyCost'))).toBe(
      true,
    );
    expect(addFields.some((s) => Object.prototype.hasOwnProperty.call(s.$addFields, 'displayAmount'))).toBe(true);
    const group = stages.find((s) => s.$group);
    expect(group.$group.totalInvestedAmount).toEqual({ $sum: '$displayAmount' });
  });
});
