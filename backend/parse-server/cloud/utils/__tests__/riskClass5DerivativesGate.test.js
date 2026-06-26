'use strict';

const {
  meetsTraderRiskClass5DerivativesExperienceCriteria,
  meetsInvestorRiskClass5DerivativesExperienceCriteria,
  cappedForRiskClass5DerivativesGate,
  enforceRiskClass5DerivativesGateOnOnboardingData,
} = require('../riskClass5DerivativesGate');

describe('riskClass5DerivativesGate', () => {
  test('trader gate requires strict derivatives profile', () => {
    expect(meetsTraderRiskClass5DerivativesExperienceCriteria({
      userRole: 'trader',
      derivativesTransactionsCount: '50+',
      derivativesInvestmentAmount: 'ten_thousand_to_hundred_thousand',
      derivativesHoldingPeriod: 'minutes_to_hours',
    })).toBe(true);

    expect(meetsTraderRiskClass5DerivativesExperienceCriteria({
      userRole: 'trader',
      derivativesTransactionsCount: '50+',
      derivativesInvestmentAmount: 'ten_thousand_to_hundred_thousand',
      derivativesHoldingPeriod: 'days_to_weeks',
    })).toBe(false);
  });

  test('investor gate accepts relaxed derivatives profile', () => {
    expect(meetsInvestorRiskClass5DerivativesExperienceCriteria({
      userRole: 'investor',
      derivativesTransactionsCount: '1-10',
      derivativesInvestmentAmount: 'thousand_to_ten_thousand',
      derivativesHoldingPeriod: 'days_to_weeks',
    })).toBe(true);

    expect(meetsInvestorRiskClass5DerivativesExperienceCriteria({
      userRole: 'investor',
      derivativesTransactionsCount: '1-10',
      derivativesInvestmentAmount: 'zero_to_thousand',
      derivativesHoldingPeriod: 'days_to_weeks',
    })).toBe(false);
  });

  test('caps risk class 5 to 4 when gate is missing', () => {
    expect(cappedForRiskClass5DerivativesGate(5, {
      userRole: 'trader',
      derivativesTransactionsCount: '1-10',
      derivativesInvestmentAmount: 'thousand_to_ten_thousand',
      derivativesHoldingPeriod: 'days_to_weeks',
    })).toBe(4);
  });

  test('enforceRiskClass5DerivativesGateOnOnboardingData mutates RC5 only', () => {
    const enforced = enforceRiskClass5DerivativesGateOnOnboardingData({
      userRole: 'trader',
      calculatedRiskClass: 5,
      finalRiskClass: 5,
      derivativesTransactionsCount: '50+',
      derivativesInvestmentAmount: 'ten_thousand_to_hundred_thousand',
      derivativesHoldingPeriod: 'days_to_weeks',
    });

    expect(enforced.calculatedRiskClass).toBe(4);
    expect(enforced.finalRiskClass).toBe(4);
  });

  test('does not cap manual risk class 7', () => {
    const enforced = enforceRiskClass5DerivativesGateOnOnboardingData({
      userRole: 'trader',
      calculatedRiskClass: 5,
      finalRiskClass: 7,
      derivativesTransactionsCount: 'None',
      derivativesInvestmentAmount: 'zero_to_thousand',
      derivativesHoldingPeriod: 'months_to_years',
    });

    expect(enforced.finalRiskClass).toBe(7);
  });
});
