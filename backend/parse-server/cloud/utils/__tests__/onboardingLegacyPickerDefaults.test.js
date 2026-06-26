'use strict';

const {
  sanitizeOnboardingSavedData,
  matchesLegacyFinancialAutosave,
  matchesLegacyExperienceAutosave,
} = require('../onboardingLegacyPickerDefaults');

describe('onboardingLegacyPickerDefaults', () => {
  const legacyFinancial = {
    employmentStatus: 'employed',
    incomeRange: 'middle',
    cashAndLiquidAssets: 'less_than_10k',
    incomeSources: { Salary: false },
  };

  const legacyExperience = {
    stocksTransactionsCount: 'None',
    stocksInvestmentAmount: 'hundred_to_ten_thousand',
    etfsTransactionsCount: 'None',
    etfsInvestmentAmount: 'hundred_to_ten_thousand',
    derivativesTransactionsCount: 'None',
    derivativesInvestmentAmount: 'zero_to_thousand',
    derivativesHoldingPeriod: 'months_to_years',
    otherAssets: { No: false },
  };

  test('detects legacy financial autosave bundle', () => {
    expect(matchesLegacyFinancialAutosave(legacyFinancial)).toBe(true);
    expect(matchesLegacyFinancialAutosave({
      ...legacyFinancial,
      employmentStatus: 'student',
    })).toBe(false);
  });

  test('detects legacy experience autosave bundle', () => {
    expect(matchesLegacyExperienceAutosave(legacyExperience)).toBe(true);
  });

  test('clears step-15 pickers when resume step is financial', () => {
    const input = { ...legacyFinancial, firstName: 'Ada' };
    const { data, changed } = sanitizeOnboardingSavedData(input, {
      currentStep: 'financial',
      progressStep: 'financial',
    });

    expect(changed).toBe(true);
    expect(data.employmentStatus).toBeUndefined();
    expect(data.incomeRange).toBeUndefined();
    expect(data.cashAndLiquidAssets).toBeUndefined();
    expect(data.firstName).toBe('Ada');
  });

  test('clears step-16 pickers when resume step is experience', () => {
    const input = { ...legacyExperience, email: 'a@b.com' };
    const { data, changed } = sanitizeOnboardingSavedData(input, {
      currentStep: 'experience',
      progressStep: 'experience',
    });

    expect(changed).toBe(true);
    expect(data.stocksTransactionsCount).toBeUndefined();
    expect(data.derivativesHoldingPeriod).toBeUndefined();
    expect(data.email).toBe('a@b.com');
  });

  test('keeps financial pickers past step 15 when income sources were selected', () => {
    const input = {
      ...legacyFinancial,
      incomeSources: { Salary: true },
    };
    const { data, changed } = sanitizeOnboardingSavedData(input, {
      currentStep: 'experience',
      progressStep: 'experience',
    });

    expect(changed).toBe(false);
    expect(data.employmentStatus).toBe('employed');
  });

  test('strips legacy financial autosave past step 15 without income sources', () => {
    const input = { ...legacyFinancial };
    const { data, changed } = sanitizeOnboardingSavedData(input, {
      currentStep: 'desiredReturn',
      progressStep: 'desiredReturn',
    });

    expect(changed).toBe(true);
    expect(data.employmentStatus).toBeUndefined();
  });

  test('is a no-op for already-unset picker fields', () => {
    const { data, changed } = sanitizeOnboardingSavedData(
      { firstName: 'Ada' },
      { currentStep: 'financial', progressStep: 'financial' },
    );

    expect(changed).toBe(false);
    expect(data.firstName).toBe('Ada');
  });
});
