'use strict';

/**
 * Per-step Joi schemas for onboarding payloads (ADR-002).
 * Mirrors legacy validateStepData rules: complete-step schemas enforce required fields;
 * partial schemas only validate shape/types when keys are present (save for later).
 */

const Joi = require('joi');

const SALUTATIONS = ['Herr', 'Frau', 'Divers', 'mr', 'mrs', 'diverse'];
const ACCOUNT_TYPES = ['individual', 'joint', 'business'];
const USER_ROLES = ['investor', 'trader'];
const IDENTIFICATION_TYPES = ['passport', 'idCard', 'driversLicense'];
const EMPLOYMENT_STATUSES = [
  'employed',
  'selfEmployed',
  'civilServant',
  'student',
  'retired',
  'unemployed',
  'other',
];
const ASSET_TYPES = ['privateAssets', 'businessAssets'];

function formatJoiError(error) {
  return error.details.map((d) => d.message.replace(/"/g, '')).join('; ');
}

function numberOrStringOptional() {
  return Joi.alternatives()
    .try(Joi.number(), Joi.string())
    .optional()
    .allow(null);
}

function createCustom(validators) {
  const { isValidBirthDate, isValidGermanPostalCode, isValidGermanTaxId } = validators;

  return {
    birthDateOptional: () =>
      Joi.any().custom((value, helpers) => {
        if (value === undefined || value === null || value === '') return value;
        if (typeof value !== 'string') return helpers.error('any.invalid');
        if (!isValidBirthDate(value)) return helpers.error('any.invalid');
        return value;
      }, 'valid birth date (18+)'),

    germanPostalOptional: () =>
      Joi.any().custom((value, helpers) => {
        if (value === undefined || value === null || value === '') return value;
        if (typeof value !== 'string') return helpers.error('any.invalid');
        if (!isValidGermanPostalCode(value)) return helpers.error('any.invalid');
        return value;
      }, 'German postal code (5 digits)'),

    germanTaxIdOptional: () =>
      Joi.any().custom((value, helpers) => {
        if (value === undefined || value === null || value === '') return value;
        if (typeof value !== 'string') return helpers.error('any.invalid');
        if (!isValidGermanTaxId(value)) return helpers.error('any.invalid');
        return value;
      }, 'German tax ID (11 digits)'),
  };
}

function buildCompleteSchemas(custom) {
  const personal = Joi.object({
    firstName: Joi.string().min(1).max(100).required(),
    lastName: Joi.string().min(1).max(100).required(),
    dateOfBirth: custom.birthDateOptional().optional(),
    salutation: Joi.string().valid(...SALUTATIONS).optional(),
    accountType: Joi.string().valid(...ACCOUNT_TYPES).optional(),
    userRole: Joi.string().valid(...USER_ROLES).optional(),
    nationality: Joi.string().min(2).max(60).optional(),
  }).unknown(true);

  const addressTax = Joi.object({
    streetAndNumber: Joi.string().min(3).max(200).required(),
    city: Joi.string().min(1).max(100).required(),
    country: Joi.string().min(1).required(),
    postalCode: custom.germanPostalOptional().optional(),
    taxNumber: custom.germanTaxIdOptional().optional(),
  }).unknown(true);

  const verification = Joi.object({
    identificationType: Joi.string().valid(...IDENTIFICATION_TYPES).optional(),
  }).unknown(true);

  const experience = Joi.object({
    questionnaireVersion: Joi.string().max(64).optional(),
    employmentStatus: Joi.string().valid(...EMPLOYMENT_STATUSES).optional(),
    income: Joi.string().optional(),
    incomeRange: Joi.string().optional(),
    incomeSources: Joi.object().pattern(Joi.string(), Joi.boolean()).optional(),
    otherIncomeSource: Joi.string().optional(),
    cashAndLiquidAssets: Joi.string().optional(),
    stocksTransactionsCount: numberOrStringOptional(),
    stocksInvestmentAmount: numberOrStringOptional(),
    etfsTransactionsCount: numberOrStringOptional(),
    etfsInvestmentAmount: numberOrStringOptional(),
    derivativesTransactionsCount: numberOrStringOptional(),
    derivativesInvestmentAmount: numberOrStringOptional(),
    derivativesHoldingPeriod: Joi.string().optional(),
    otherAssets: Joi.object().pattern(Joi.string(), Joi.boolean()).optional(),
    leveragedProductsExperience: Joi.boolean().optional(),
    financialProductsExperience: Joi.boolean().optional(),
  }).unknown(true);

  const risk = Joi.object({
    questionnaireVersion: Joi.string().max(64).optional(),
    desiredReturn: Joi.string().optional(),
    calculatedRiskClass: Joi.number().integer().min(0).optional().allow(null),
    finalRiskClass: Joi.number().integer().min(0).optional().allow(null),
    insiderTradingOptions: Joi.object().pattern(Joi.string(), Joi.boolean()).optional(),
    moneyLaunderingDeclaration: Joi.boolean().optional(),
    assetType: Joi.string().valid(...ASSET_TYPES).optional(),
  }).unknown(true);

  // Match legacy rules: explicit false is invalid; missing keys allowed (strict booleans only when present).
  const consents = Joi.object({
    acceptedTerms: Joi.boolean().strict().invalid(false).optional(),
    acceptedPrivacyPolicy: Joi.boolean().strict().invalid(false).optional(),
    acceptedMarketingConsent: Joi.boolean().strict().optional(),
    termsVersion: Joi.string().min(1).max(20).optional(),
    privacyVersion: Joi.string().min(1).max(20).optional(),
  }).unknown(true);

  return {
    personal,
    address: addressTax,
    tax: addressTax,
    verification,
    experience,
    risk,
    consents,
  };
}

function buildPartialSchemas(custom) {
  const namePart = Joi.string().min(1).max(100).optional();
  const personal = Joi.object({
    firstName: namePart,
    lastName: namePart,
    dateOfBirth: custom.birthDateOptional().optional(),
    salutation: Joi.string().valid(...SALUTATIONS).optional(),
    accountType: Joi.string().valid(...ACCOUNT_TYPES).optional(),
    userRole: Joi.string().valid(...USER_ROLES).optional(),
    nationality: Joi.string().min(2).max(60).optional(),
  }).unknown(true);

  const addressTax = Joi.object({
    streetAndNumber: Joi.string().min(3).max(200).optional(),
    city: Joi.string().min(1).max(100).optional(),
    country: Joi.string().min(1).optional(),
    postalCode: custom.germanPostalOptional().optional(),
    taxNumber: custom.germanTaxIdOptional().optional(),
  }).unknown(true);

  const verification = Joi.object({
    identificationType: Joi.string().valid(...IDENTIFICATION_TYPES).optional(),
  }).unknown(true);

  const experience = Joi.object({
    questionnaireVersion: Joi.string().max(64).optional(),
    employmentStatus: Joi.string().valid(...EMPLOYMENT_STATUSES).optional(),
    income: Joi.string().optional(),
    incomeRange: Joi.string().optional(),
    incomeSources: Joi.object().pattern(Joi.string(), Joi.boolean()).optional(),
    otherIncomeSource: Joi.string().optional(),
    cashAndLiquidAssets: Joi.string().optional(),
    stocksTransactionsCount: numberOrStringOptional(),
    stocksInvestmentAmount: numberOrStringOptional(),
    etfsTransactionsCount: numberOrStringOptional(),
    etfsInvestmentAmount: numberOrStringOptional(),
    derivativesTransactionsCount: numberOrStringOptional(),
    derivativesInvestmentAmount: numberOrStringOptional(),
    derivativesHoldingPeriod: Joi.string().optional(),
    otherAssets: Joi.object().pattern(Joi.string(), Joi.boolean()).optional(),
    leveragedProductsExperience: Joi.boolean().optional(),
    financialProductsExperience: Joi.boolean().optional(),
  }).unknown(true);

  const risk = Joi.object({
    questionnaireVersion: Joi.string().max(64).optional(),
    desiredReturn: Joi.string().optional(),
    calculatedRiskClass: Joi.number().integer().min(0).optional().allow(null),
    finalRiskClass: Joi.number().integer().min(0).optional().allow(null),
    insiderTradingOptions: Joi.object().pattern(Joi.string(), Joi.boolean()).optional(),
    moneyLaunderingDeclaration: Joi.boolean().optional(),
    assetType: Joi.string().valid(...ASSET_TYPES).optional(),
  }).unknown(true);

  const consents = Joi.object({
    acceptedTerms: Joi.boolean().strict().invalid(false).optional(),
    acceptedPrivacyPolicy: Joi.boolean().strict().invalid(false).optional(),
    acceptedMarketingConsent: Joi.boolean().strict().optional(),
    termsVersion: Joi.string().min(1).max(20).optional(),
    privacyVersion: Joi.string().min(1).max(20).optional(),
  }).unknown(true);

  return {
    personal,
    address: addressTax,
    tax: addressTax,
    verification,
    experience,
    risk,
    consents,
  };
}

/**
 * @param {{ isValidBirthDate: Function, isValidGermanPostalCode: Function, isValidGermanTaxId: Function }} validators
 */
function createValidateStepData(validators) {
  const custom = createCustom(validators);
  const completeSchemas = buildCompleteSchemas(custom);

  return function validateStepData(step, data) {
    if (!data) return { valid: true };
    const schema = completeSchemas[step];
    if (!schema) return { valid: true };

    const { error } = schema.validate(data, { abortEarly: false, stripUnknown: false });
    if (error) {
      return { valid: false, message: formatJoiError(error) };
    }
    return { valid: true };
  };
}

/**
 * Partial progress: validate types/enums only when fields are sent (no required fields).
 */
function createValidatePartialOnboardingData(validators) {
  const custom = createCustom(validators);
  const partialSchemas = buildPartialSchemas(custom);

  return function validatePartialOnboardingData(step, data) {
    if (!data) return { valid: true };
    const schema = partialSchemas[step];
    if (!schema) {
      return { valid: true };
    }

    const { error } = schema.validate(data, { abortEarly: false, stripUnknown: false });
    if (error) {
      return { valid: false, message: formatJoiError(error) };
    }
    return { valid: true };
  };
}

module.exports = {
  createValidateStepData,
  createValidatePartialOnboardingData,
};
