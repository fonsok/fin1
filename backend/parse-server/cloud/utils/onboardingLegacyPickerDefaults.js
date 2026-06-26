'use strict';

const SIGNUP_STEP_NUMBERS = require('../contracts/signUpStepNumbers.json');

const STEP15_PICKER_FIELDS = [
  'employmentStatus',
  'incomeRange',
  'cashAndLiquidAssets',
];

const STEP16_PICKER_FIELDS = [
  'stocksTransactionsCount',
  'stocksInvestmentAmount',
  'etfsTransactionsCount',
  'etfsInvestmentAmount',
  'derivativesTransactionsCount',
  'derivativesInvestmentAmount',
  'derivativesHoldingPeriod',
];

/** Old iOS non-optional defaults auto-saved on every partial progress write. */
const LEGACY_EXPERIENCE_AUTOSAVE = {
  stocksTransactionsCount: 'None',
  stocksInvestmentAmount: 'hundred_to_ten_thousand',
  etfsTransactionsCount: 'None',
  etfsInvestmentAmount: 'hundred_to_ten_thousand',
  derivativesTransactionsCount: 'None',
  derivativesInvestmentAmount: 'zero_to_thousand',
  derivativesHoldingPeriod: 'months_to_years',
};

/** DEBUG prefill variant that also leaked into saved progress blobs. */
const LEGACY_EXPERIENCE_DEBUG_PREFILL = {
  stocksTransactionsCount: '1-10',
  stocksInvestmentAmount: 'ten_thousand_to_hundred_thousand',
  etfsTransactionsCount: '1-10',
  etfsInvestmentAmount: 'ten_thousand_to_hundred_thousand',
  derivativesTransactionsCount: 'None',
  derivativesInvestmentAmount: 'zero_to_thousand',
  derivativesHoldingPeriod: 'months_to_years',
};

function resolveResumeStepNumber(currentStep, progressStep) {
  const fromUser = SIGNUP_STEP_NUMBERS[currentStep];
  if (fromUser != null) return fromUser;
  const fromProgress = SIGNUP_STEP_NUMBERS[progressStep];
  if (fromProgress != null) return fromProgress;
  return null;
}

function hasTruthySelection(map) {
  if (!map || typeof map !== 'object') return false;
  return Object.values(map).some((value) => value === true);
}

function matchesLegacyFinancialAutosave(data) {
  if (!data) return false;
  const { employmentStatus, incomeRange, cashAndLiquidAssets } = data;
  return employmentStatus === 'employed'
    && incomeRange === 'middle'
    && (cashAndLiquidAssets === 'less_than_10k' || cashAndLiquidAssets === 'ten_k_to_fifty_k');
}

function matchesExperienceBundle(data, bundle) {
  if (!data) return false;
  return Object.entries(bundle).every(([field, expected]) => data[field] === expected);
}

function matchesLegacyExperienceAutosave(data) {
  return matchesExperienceBundle(data, LEGACY_EXPERIENCE_AUTOSAVE)
    || matchesExperienceBundle(data, LEGACY_EXPERIENCE_DEBUG_PREFILL);
}

function clearFields(data, fields) {
  const next = { ...data };
  let changed = false;
  for (const field of fields) {
    if (Object.prototype.hasOwnProperty.call(next, field) && next[field] != null) {
      delete next[field];
      changed = true;
    }
  }
  return { data: next, changed };
}

function shouldClearStep15Pickers(data, resumeStepNumber) {
  if (resumeStepNumber != null && resumeStepNumber <= 15) return true;
  if (resumeStepNumber != null && resumeStepNumber > 15) {
    return !hasTruthySelection(data?.incomeSources) && matchesLegacyFinancialAutosave(data);
  }
  return !hasTruthySelection(data?.incomeSources) && matchesLegacyFinancialAutosave(data);
}

function shouldClearStep16Pickers(data, resumeStepNumber) {
  if (resumeStepNumber != null && resumeStepNumber <= 16) return true;
  if (resumeStepNumber != null && resumeStepNumber > 16) {
    return !hasTruthySelection(data?.otherAssets) && matchesLegacyExperienceAutosave(data);
  }
  return !hasTruthySelection(data?.otherAssets) && matchesLegacyExperienceAutosave(data);
}

/**
 * Removes phantom step-15/16 picker values from onboarding progress blobs.
 * Mirrors the iOS resume rules and strips known legacy auto-default bundles.
 */
function sanitizeOnboardingSavedData(data, { currentStep, progressStep } = {}) {
  if (!data || typeof data !== 'object') {
    return { data, changed: false };
  }

  const resumeStepNumber = resolveResumeStepNumber(currentStep, progressStep);
  let next = { ...data };
  let changed = false;

  if (shouldClearStep15Pickers(next, resumeStepNumber)) {
    const cleared = clearFields(next, STEP15_PICKER_FIELDS);
    next = cleared.data;
    changed = changed || cleared.changed;
  }

  if (shouldClearStep16Pickers(next, resumeStepNumber)) {
    const cleared = clearFields(next, STEP16_PICKER_FIELDS);
    next = cleared.data;
    changed = changed || cleared.changed;
  }

  return { data: next, changed };
}

module.exports = {
  SIGNUP_STEP_NUMBERS,
  STEP15_PICKER_FIELDS,
  STEP16_PICKER_FIELDS,
  sanitizeOnboardingSavedData,
  resolveResumeStepNumber,
  matchesLegacyFinancialAutosave,
  matchesLegacyExperienceAutosave,
};
