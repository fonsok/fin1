'use strict';

const { readInvestmentCommissionRateSnapshot } = require('../commissionRateSnapshot');

function makeInvestment(snapshot) {
  return {
    get(key) {
      if (key === 'commissionRateBundleSnapshot') return snapshot;
      return undefined;
    },
  };
}

describe('readInvestmentCommissionRateSnapshot', () => {
  it('returns null when investment or snapshot is missing', () => {
    expect(readInvestmentCommissionRateSnapshot(null)).toBeNull();
    expect(readInvestmentCommissionRateSnapshot(makeInvestment(null))).toBeNull();
  });

  it('reads valid snapshot as settlement rates', () => {
    const result = readInvestmentCommissionRateSnapshot(makeInvestment({
      investorCommissionRateTotal: 0.08,
      traderCommissionRate: 0.05,
      appCommissionRate: 0.03,
      source: 'investor',
    }));
    expect(result).toEqual({
      traderRate: 0.05,
      appRate: 0.03,
      totalRate: 0.08,
      source: 'investment_snapshot',
      bundle: {
        investorCommissionRateTotal: 0.08,
        traderCommissionRate: 0.05,
        appCommissionRate: 0.03,
      },
    });
  });

  it('rejects invalid bundle sums', () => {
    expect(readInvestmentCommissionRateSnapshot(makeInvestment({
      investorCommissionRateTotal: 0.1,
      traderCommissionRate: 0.06,
      appCommissionRate: 0.05,
    }))).toBeNull();
  });
});
